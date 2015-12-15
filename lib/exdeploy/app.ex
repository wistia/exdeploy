defmodule Exdeploy.App do
  alias Exdeploy.Project
  alias Exdeploy.Release
  alias Exdeploy.App

  defstruct [
    name: nil,
    path: nil,
    deploy_path: nil,
    project: nil
  ]

  def build(app) do
    mix app, "release"
  end

  def full_build(app) do
    deps_get(app)
    compile(app)
    build(app)
  end

  def deps_get(app) do
    mix app, "deps.get"
  end

  def compile(app) do
    mix app, "compile"
  end

  def release_clean(app) do
    mix app, "release.clean"
  end

  def release_clean_implode(app) do
    mix app, "release.clean --implode"
  end

  def rm_rel(app) do
    File.rm_rf "#{app.path}/rel"
  end

  def mix(app, cmd, env \\ [], opts \\ []) do
    args = String.split(cmd, " ")
    env = [{"MIX_ENV", "prod"}] ++ env
    opts = [env: env, cd: app.path, stderr_to_stdout: true] ++ opts
    IO.inspect {env, app.path, "mix", cmd}
    {output, exit_status} = System.cmd("mix", args, opts)
    IO.puts output
    {output, exit_status}
  end

  def current_version(app) do
    case File.read("#{app.deploy_path}/releases/start_erl.data") do
      {:ok, content} ->
        [_, release] = String.split(content, " ")
        release
      _else ->
        nil
    end
  end

  def current_release(app) do
    release(app, current_version(app))
  end

  def latest_release(app) do
    releases(app) |> List.last
  end

  def release(app, version) do
    releases(app)
    |> Enum.find(fn(release) -> version == release.version end)
  end

  def latest_version(app) do
    latest_release(app).version
  end

  def versions(app) do
    Release.paths_for_app(app)
    |> Enum.map(&Release.version_from_path(&1))
    |> Enum.sort
  end

  def releases(app) do
    versions(app) |> Enum.map(&Release.new(app, &1))
  end

  def never_deployed?(app) do
    !deployed?(app)
  end

  def deployed?(app) do
    !!current_version(app)
  end

  def running?(app) do
    App.current_release(app) |> Release.running?
  end

  def running_version(app) do
    case ping(app) do
      {text, 0} ->
        [line1 | _] = String.split(text, "\n")
        regex = Regex.compile!("#{app.deploy_path}/releases/(\\d+\\.\\d+\\.\\d+)/#{app.name}")
        [_, version] = Regex.run(regex, line1)
        version
      _else ->
        nil
    end
  end

  def start(app) do
    app |> bin("start")
  end

  def stop(app) do
    app |> bin("stop")
  end

  def restart(app) do
    app |> bin("restart")
  end

  def ping(app) do
    app |> bin("ping")
  end

  def bin(app, cmd) do
    if deployed?(app) do
      if release = App.current_release(app) do
        release |> Release.bin(cmd)
      else
        IO.puts "#{app.name}: No releases available, skipping cmd #{cmd}"
      end
    else
      IO.puts "App #{app.name} has never been deployed. Skipping command #{cmd}"
    end
  end
end
