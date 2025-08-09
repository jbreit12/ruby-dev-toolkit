# lib/rdt/git_helper.rb
# frozen_string_literal: true

require "shellwords"

module RDT
  class GitHelper
    DEVNULL = Gem.win_platform? ? "NUL" : "/dev/null"

    DEFAULTS = {
      "remoteName"   => "origin",
      "defaultBase"  => "dev",
      "syncStrategy" => "rebase", # or "merge"
      "enforcePrefix"=> true,
      "allowedPrefixes" => ["feature/", "bugfix/", "hotfix/"],
      "logLevel"     => "info"
    }

    # ---------------- entry point ----------------
    def self.run(argv = [])
      @args = argv.dup
      @cfg  = DEFAULTS.dup
      @dry  = take_flag!(%w[--dry-run])
      @verb = take_flag!(%w[--verbose -v])

      action = @args.shift
      if action.nil? || action == "" || %w[help -h --help].include?(action)
        help
        return
      end

      case action
      when "help"        then help
      when "status"      then status
      when "fetch"       then fetch_all
      when "list"        then list
      when "init"        then init_repo
      when "gitignore"   then write_gitignore(:preset => (opt_value(%w[--preset -p]) || "ruby"))
      when "firstcommit" then first_commit
      when "remote"      then set_remote(:url => required(opt_value(%w[--url])))
      when "remote"   then set_remote(:url => required(opt_value(%w[--url]), "--url"))
      when "branch"   then ensure_branch(:name => required(opt_value(%w[--name -n]), "--name"))
      when "checkout" then checkout(:name => required(opt_value(%w[--name -n]), "--name"))
      when "newbranch"then newbranch(:name => required(opt_value(%w[--name -n]), "--name"))
      when "commitpush" then commit_push(:message => required(opt_value(%w[--message -m]), "-m"))
      when "pull"        then pull_current
      when "sync"        then sync_with_base
      when "prune"       then prune
      when "upstream"    then ensure_upstream
      
      else
        puts "Unknown action: #{action.inspect}\n\n"
        help
      end
    end

    # ---------------- actions ----------------
    def self.help
      puts <<~H
        Usage: rdt git_helper <action> [options] [--dry-run] [--verbose]

        Actions:
          status                        # show short status + upstream info
          fetch                         # git fetch --all --prune
          list                          # list local & remote branches
          init                          # git init if not repo
          gitignore [--preset=ruby]     # write .gitignore if missing (ruby|node|python|minimal)
          firstcommit                   # stage all and create initial commit
          remote --url=<git-url>        # add or update origin
          branch --name=<branch>        # ensure you are on <branch> (create/rename as needed)
          checkout --name=<branch>      # checkout existing/local/remote branch (or create from base)
          newbranch --name=<branch>     # create new branch from #{@cfg["defaultBase"]}
          commitpush -m "<msg>"         # add -A, commit, push (sets upstream)
          pull                          # pull current branch (rebase/merge per config)
          sync                          # rebase/merge current branch on #{@cfg["defaultBase"]}
          prune                         # fetch --all --prune and remote prune origin
          upstream                      # set upstream to origin/current if missing

        Flags:
          --dry-run   print commands without executing
          --verbose   show each command as it runs

        Examples:
          rdt git_helper status
          rdt git_helper checkout --name=feature/readme-gen
          rdt git_helper newbranch --name=bugfix/fix-thing
          rdt git_helper commitpush -m "feat: add readme generator"
          rdt git_helper remote --url=git@github.com:user/repo.git
      H
    end

    def self.status
      exec_cmd "git status -sb"
      branch = backtick("git rev-parse --abbrev-ref HEAD").strip
      upstream_ok = system("git rev-parse --abbrev-ref --symbolic-full-name @{u} >#{DEVNULL} 2>&1")
      puts "(no upstream set for #{branch})" unless upstream_ok
    end

    def self.fetch_all
      exec_cmd "git fetch --all --prune"
    end

    def self.list
      puts "Local branches:"
      exec_cmd "git branch"
      puts "Remote branches:"
      exec_cmd "git branch -r"
    end

    def self.required(val, flag_name = nil)
      if val.nil? || val.strip.empty?
        msg = "Missing required option"
        msg += " #{flag_name}" if flag_name
        puts msg
        exit 2
      end
      val
    end

    def self.init_repo
      if Dir.exist?(".git")
        puts "Already a git repo; skipping init."
      else
        exec_cmd "git init"
        puts "Repository initialized."
      end
    end

    def self.gitignore_preset(name)
      case name.to_s.downcase
      when "ruby"
        <<~GI
          # Ruby / Bundler
          *.gem
          *.rbc
          /.bundle/
          /vendor/bundle/
          .bundle/
          .byebug_history
          coverage/
          pkg/
          tmp/
          # macOS
          .DS_Store
        GI
      when "node"   then "node_modules/\ndist/\n.DS_Store\n"
      when "python" then "__pycache__/\n*.py[cod]\n.env/\n.venv/\n.DS_Store\n"
      when "minimal"then ".DS_Store\ntmp/\n"
      else              "# .gitignore\n"
      end
    end

    def self.write_gitignore(opts = {})
      preset = opts[:preset] || "ruby"
      if File.exist?(".gitignore")
        puts ".gitignore exists; skipping."
        return
      end
      File.write(".gitignore", gitignore_preset(preset))
      puts "Wrote .gitignore (preset: #{preset})"
    end

    def self.first_commit
      ok = system("git rev-parse --verify HEAD >#{DEVNULL} 2>&1")
      if ok
        puts "Repo already has commits; skipping initial commit."
        return
      end
      exec_cmd "git add -A"
      if system('git commit -m "Initial commit"')
        puts "Created initial commit."
      else
        puts "Nothing to commit."
      end
    end

    def self.set_remote(opts = {})
      url = opts[:url].to_s
      remote = @cfg["remoteName"]
      if system("git remote get-url #{sh(remote)} >#{DEVNULL} 2>&1")
        puts "Updating remote '#{remote}' -> #{url}"
        exec_cmd "git remote set-url #{sh(remote)} #{sh(url)}"
      else
        puts "Adding remote '#{remote}' -> #{url}"
        exec_cmd "git remote add #{sh(remote)} #{sh(url)}"
      end
    end

    def self.ensure_branch(opts = {})
      name = opts[:name].to_s
      check_prefix!(name)
      current = backtick("git branch --show-current").strip
      if current.empty?
        exec_cmd "git checkout -b #{sh(name)}"
      elsif current != name
        puts "Renaming branch #{current} -> #{name}"
        exec_cmd "git branch -M #{sh(name)}"
      else
        puts "Already on #{name}"
      end
    end

    def self.checkout(opts = {})
      name = opts[:name].to_s
      check_prefix!(name)
      # local?
      if system("git show-ref --verify --quiet refs/heads/#{sh(name)}")
        exec_cmd "git checkout #{sh(name)}"
        return
      end
      # remote?
      remote = @cfg["remoteName"]
      if system("git ls-remote --exit-code --heads #{sh(remote)} #{sh(name)} >#{DEVNULL} 2>&1")
        exec_cmd "git checkout -b #{sh(name)} #{sh(remote)}/#{sh(name)}"
        return
      end
      # create from base
      base = @cfg["defaultBase"]
      exec_cmd "git checkout -b #{sh(name)} #{sh(remote)}/#{sh(base)}"
    end

    def self.newbranch(opts = {})
      name = opts[:name].to_s
      check_prefix!(name)
      base = @cfg["defaultBase"]
      remote = @cfg["remoteName"]
      exec_cmd "git checkout -b #{sh(name)} #{sh(remote)}/#{sh(base)}"
    end

    def self.commit_push(opts = {})
      message = opts[:message].to_s
      if message.strip.empty?
        puts "Missing commit message (-m)"; exit 2
      end
      exec_cmd "git add -A"
      committed = system(%(git commit -m #{sq(message)}))
      puts "Nothing to commit" unless committed
      branch = backtick("git rev-parse --abbrev-ref HEAD").strip
      remote = @cfg["remoteName"]
      exec_cmd "git push --set-upstream #{sh(remote)} #{sh(branch)}"
    end

    def self.pull_current
      branch = backtick("git rev-parse --abbrev-ref HEAD").strip
      remote = @cfg["remoteName"]
      stash = !backtick("git status --porcelain").strip.empty?
      exec_cmd "git stash" if stash
      if @cfg["syncStrategy"] == "rebase"
        exec_cmd "git pull --rebase #{sh(remote)} #{sh(branch)}"
      else
        exec_cmd "git pull #{sh(remote)} #{sh(branch)}"
      end
      exec_cmd "git stash pop" if stash
    end

    def self.sync_with_base
      base   = @cfg["defaultBase"]
      remote = @cfg["remoteName"]
      stash = !backtick("git status --porcelain").strip.empty?
      exec_cmd "git stash" if stash
      exec_cmd "git fetch #{sh(remote)} #{sh(base)}"
      if @cfg["syncStrategy"] == "rebase"
        ok = system("git rebase #{sh(remote)}/#{sh(base)}")
        unless ok
          puts "Conflicts. Resolve, then: git add -A && git rebase --continue (or --abort)"
          exit 6
        end
      else
        ok = system("git merge --no-ff #{sh(remote)}/#{sh(base)}")
        unless ok
          puts "Conflicts. Resolve, then: git add -A && git merge --continue (or --abort)"
          exit 6
        end
      end
      exec_cmd "git stash pop" if stash
    end

    def self.prune
      remote = @cfg["remoteName"]
      exec_cmd "git fetch --all --prune"
      exec_cmd "git remote prune #{sh(remote)}"
    end

    def self.ensure_upstream
      branch = backtick("git rev-parse --abbrev-ref HEAD").strip
      ok = system("git rev-parse --abbrev-ref --symbolic-full-name @{u} >#{DEVNULL} 2>&1")
      unless ok
        remote = @cfg["remoteName"]
        exec_cmd "git push --set-upstream #{sh(remote)} #{sh(branch)}"
      end
    end

    # ---------------- small helpers ----------------
    def self.check_prefix!(name)
      return true unless @cfg["enforcePrefix"]
      allowed = @cfg["allowedPrefixes"] || []
      return true if allowed.any? { |p| name.start_with?(p) }
      puts "Branch name must start with one of: #{allowed.join(' ')}"
      exit 2
    end

    def self.take_flag!(keys)
      i = @args.index { |a| keys.include?(a) }
      @args.delete_at(i) if i
      !!i
    end

    # supports "--key=value" or "--key value" or "-k value"
    def self.opt_value(keys)
      idx = @args.index { |a| keys.any? { |k| a.start_with?("#{k}=") } }
      if idx
        val = @args[idx].split("=", 2)[1]
        @args.delete_at(idx)
        return val
      end
      idx2 = @args.index { |a| keys.include?(a) }
      if idx2
        val = @args[idx2 + 1]
        @args.slice!(idx2, 2)
        return val
      end
      nil
    end

    def self.backtick(cmd)
      IO.popen(cmd, :err => File::NULL, &:read) || ""
    rescue
      ""
    end

    def self.exec_cmd(cmd)
      printable = cmd.is_a?(Array) ? cmd.map(&:to_s).join(" ") : cmd.to_s
      puts("$ #{printable}") if @verb || @dry
      return true if @dry
      ok = cmd.is_a?(Array) ? system(*cmd.map(&:to_s)) : system(cmd.to_s)
      unless ok
        puts "Command failed: #{printable.inspect}"
        exit 6
      end
      true
    end

    def self.sh(s)
      Shellwords.escape(s.to_s)
    end

    def self.sq(s)
      "'" + s.to_s.gsub("'", %q('\'')) + "'"
    end
  end
end
