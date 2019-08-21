require 'aruba/cucumber'
require 'fileutils'
require 'forwardable'
require 'tmpdir'

system_git = `which git 2>/dev/null`.chomp
bin_dir = File.expand_path('../fakebin', __FILE__)
hub_dir = Dir.mktmpdir('hub_build')
raise 'hub build failed' unless system("./script/build -o #{hub_dir}/hub")

Before do
  # speed up load time by skipping RubyGems
  set_environment_variable 'RUBYOPT', '--disable-gems' if RUBY_VERSION > '1.9'
  # put fakebin on the PATH
  set_environment_variable 'PATH', "#{hub_dir}:#{bin_dir}:#{ENV['PATH']}"
  # clear out GIT if it happens to be set
  set_environment_variable 'GIT', nil
  # exclude this project's git directory from use in testing
  set_environment_variable 'GIT_CEILING_DIRECTORIES', File.expand_path('../../..', __FILE__)
  # sabotage git commands that might try to access a remote host
  set_environment_variable 'GIT_PROXY_COMMAND', 'echo'
  # avoids reading from current user's "~/.gitconfig"
  set_environment_variable 'HOME', expand_path('home')
  set_environment_variable 'TMPDIR', expand_path('tmp')
  # https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html#variables
  set_environment_variable 'XDG_CONFIG_HOME', nil
  set_environment_variable 'XDG_CONFIG_DIRS', nil
  # used in fakebin/git
  set_environment_variable 'HUB_SYSTEM_GIT', system_git
  # ensure that api.github.com is actually never hit in tests
  set_environment_variable 'HUB_TEST_HOST', 'http://127.0.0.1:0'
  # ensure we use fakebin `open` to test browsing
  set_environment_variable 'BROWSER', 'open'
  # sabotage opening a commit message editor interactively
  set_environment_variable 'GIT_EDITOR', 'false'
  # reset current localization settings
  set_environment_variable 'LANG', nil
  set_environment_variable 'LANGUAGE', nil
  set_environment_variable 'LC_ALL', 'en_US.UTF-8'
  # ignore current user's token
  set_environment_variable 'GITHUB_TOKEN', nil
  set_environment_variable 'GITHUB_USER', nil
  set_environment_variable 'GITHUB_PASSWORD', nil
  set_environment_variable 'GITHUB_HOST', nil

  author_name  = "Hub"
  author_email = "hub@test.local"
  set_environment_variable 'GIT_AUTHOR_NAME',     author_name
  set_environment_variable 'GIT_COMMITTER_NAME',  author_name
  set_environment_variable 'GIT_AUTHOR_EMAIL',    author_email
  set_environment_variable 'GIT_COMMITTER_EMAIL', author_email

  set_environment_variable 'HUB_VERSION', 'dev'
  set_environment_variable 'HUB_REPORT_CRASH', 'never'
  set_environment_variable 'HUB_PROTOCOL', nil

  FileUtils.mkdir_p(expand_path('~'))

  # increase process exit timeout from the default of 3 seconds
  @aruba_timeout_seconds = 10
  # don't be "helpful"
  @aruba_keep_ansi = true
end

After do
  @server.stop if defined? @server and @server
  FileUtils.rm_f("#{bin_dir}/vim")
end

RSpec::Matchers.define :be_successfully_executed do
  match do |cmd|
    expect(cmd).to have_exit_status(0)
  end

  failure_message do |cmd|
    msg = %(command `#{cmd.commandline}` exited with status #{cmd.exit_status})
    stderr = cmd.stderr
    msg << ":\n" << stderr.gsub(/^/, '  ') unless stderr.empty?
    msg
  end
end

class SimpleCommand
  attr_reader :output

  def initialize cmd
    @cmd = cmd
  end

  def to_s
    @cmd
  end

  def self.run cmd
    command = new(cmd)
    command.run
    command
  end

  def run
    @output = `#{@cmd} 2>&1`.chomp
    @status = $?
    $?.success?
  end

  def stop
  end
  alias stderr output
  alias commandline to_s

  def exit_status
    @status.exitstatus
  end
end

World Module.new {
  # If there are multiple inputs, e.g., type in username and then type in password etc.,
  # the Go program will freeze on the second input. Giving it a small time interval
  # temporarily solves the problem.
  # See https://github.com/cucumber/aruba/blob/7afbc5c0cbae9c9a946d70c4c2735ccb86e00f08/lib/aruba/api.rb#L379-L382
  def type(*args)
    super.tap { sleep 0.1 }
  end

  def history
    histfile = expand_path('~/.history')
    if File.exist? histfile
      File.readlines histfile
    else
      []
    end
  end

  def assert_command_run cmd
    cmd += "\n" unless cmd[-1..-1] == "\n"
    expect(history).to include(cmd)
  end

  def edit_hub_config
    config = expand_path('~/.config/hub')
    FileUtils.mkdir_p File.dirname(config)
    if File.exist? config
      data = YAML.load File.read(config)
    else
      data = {}
    end
    yield data
    File.open(config, 'w') { |cfg| cfg << YAML.dump(data) }
  end

  define_method(:text_editor_script) do |bash_code|
    File.open("#{bin_dir}/vim", 'w', 0755) { |exe|
      exe.puts "#!/bin/bash"
      exe.puts "set -e"
      exe.puts bash_code
    }
  end

  def run_silent cmd
    in_current_directory do
      command = SimpleCommand.run(cmd)
      expect(command).to be_successfully_executed
      command.output
    end
  end

  def empty_commit(message = nil)
    unless message
      @empty_commit_count = defined?(@empty_commit_count) ? @empty_commit_count + 1 : 1
      message = "empty #{@empty_commit_count}"
    end
    run_silent "git commit --quiet -m '#{message}' --allow-empty"
  end

  # Aruba unnecessarily creates new Announcer instance on each invocation
  def announcer
    @announcer ||= super
  end

  def shell_escape(message)
    message.to_s.gsub(/['"\\ $]/) { |m| "\\#{m}" }
  end

  %w[output_from stdout_from stderr_from all_output all_stdout all_stderr].each do |m|
    define_method(m) do |*args|
      home = aruba.environment['HOME'].to_s
      output = super(*args)
      if home.empty?
        output
      else
        output.gsub(home, '$HOME')
      end
    end
  end
}
