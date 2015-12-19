defmodule Exdeploy.App do
  require Logger
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

  def full_build(app, options \\ []) do
    install_hex(app)
    install_rebar(app)
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

  def install_hex(app) do
    mix app, "local.hex --force"
  end

  def install_rebar(app) do
    mix app, "local.rebar --force"
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
    Logger.info inspect {env, app.path, "mix", cmd}
    {output, exit_status} = System.cmd("mix", args, opts)
    Logger.debug output
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

  def running?(app, options \\ []) do
    App.current_release(app) |> Release.running?(options)
  end

  def running_version(app, options \\ []) do
    case ping(app, options) do
      {text, 0} ->
        [line1 | _] = String.split(text, "\n")
        regex = Regex.compile!("#{app.deploy_path}/releases/(\\d+\\.\\d+\\.\\d+)/#{app.name}")
        [_, version] = Regex.run(regex, line1)
        version
      _else ->
        nil
    end
  end

  def start(app, options \\ []) do
    app |> bin("start", options)
  end

  def stop(app, options \\ []) do
    app |> bin("stop", options)
  end

  def restart(app, options \\ []) do
    app |> bin("restart", options)
  end

  def ping(app, options \\ []) do
    app |> bin("ping", options)
  end

  def bin(app, cmd, options \\ []) do
    if deployed?(app) do
      if release = App.current_release(app) do
        release |> Release.bin(cmd, options)
      else
        Logger.warn "#{app.name}: No releases available, skipping cmd #{cmd}"
      end
    else
      Logger.warn "App #{app.name} has never been deployed. Skipping command #{cmd}"
    end
  end
end
