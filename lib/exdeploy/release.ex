defmodule Exdeploy.Release do
  require Logger
  alias Exdeploy.Release
  alias Exdeploy.App

  defstruct [
    app: nil,
    path: nil,
    version: nil,
    release_dir: nil,
    tarball: nil,
  ]

  def new(app, version) do
    %Release{
      app: app,
      version: version,
      path: path(app, version),
      tarball: tarball(app, version),
      release_dir: release_dir(app, version)
    }
  end

  def paths_for_app(%App{path: path, name: name}) do
    Path.expand("#{path}/rel/#{name}/releases/*")
    |> Path.wildcard
    |> Enum.filter(&File.dir?/1)
  end

  def version_from_path(path) do
    [version | _] = String.split(path, "/") |> Enum.reverse
    version
  end

  def install(release, options \\ []) do
    if App.running?(release.app) do
      raise "Can't install #{inspect release};
      App version #{inspect App.current_version(release.app)} is already
      running. Try using upgrade or downgrade instead."
    else
      Logger.info "#{release.app.name}: Installing a brand new app, starting at version #{release.version}"
      File.mkdir_p(release.app.deploy_path)
      File.cp(release.tarball, "#{release.app.project.deploy_path}/#{release.app.name}.tar.gz")
      Logger.info "cd #{release.app.deploy_path} && tar -xf #{release.tarball}"
      result = System.cmd("tar", ~w[-xf #{release.tarball}], cd: release.app.deploy_path)
      Logger.debug inspect(result)
      if options[:user] do
        System.cmd("chown", ~w[-R #{options[:user]} #{release.app.deploy_path}])
      end
      if options[:group] do
        System.cmd("chgrp", ~w[-R #{options[:group]} #{release.app.deploy_path}])
      end
      release |> bin("start", user: options[:user])
    end
  end

  def upgrade(release, options \\ []) do
    if App.current_version(release.app) == nil do
      raise "Can't upgrade #{inspect release};
      No version has been deployed yet. Try using install instead."
    else
      Logger.info "#{release.app.name}: Upgrading from #{App.current_version(release.app)} to #{release.version}"
      File.mkdir_p(release.release_dir)
      File.cp(release.tarball, "#{release.release_dir}/#{release.app.name}.tar.gz")
      if options[:user] do
        System.cmd("chown", ~w[-R #{options[:user]} #{release.release_dir}])
      end
      if options[:group] do
        System.cmd("chgrp", ~w[-R #{options[:group]} #{release.release_dir}])
      end
      release |> bin("upgrade #{release.version}", user: options[:user])
    end
  end

  def bin(release, cmd, options \\ []) do
    prefix = if options[:user] do
      "sudo -Hu #{options[:user]} #{release.app.deploy_path}/bin/#{release.app.name}"
    else
      "#{release.app.deploy_path}/bin/#{release.app.name}"
    end
    [bin | args] = String.split(prefix, " ") ++ String.split(cmd, " ")
    Logger.info bin <> " " <> Enum.join(args, " ")
    result = System.cmd(bin, args, cd: release.app.deploy_path)
    Logger.debug inspect(result)
    result
  end

  def extract(%Release{release_dir: release_dir, tarball: tarball}) do
    unless extracted?(release_dir) do
      Logger.debug "Extracting #{tarball} to #{release_dir}"
      File.mkdir_p(release_dir)
      result = System.cmd("tar", ~w[-xf #{tarball} --directory #{release_dir}])
      Logger.debug inspect(result)
      result
    end
  end

  def running?(release, options \\ []) do
    if release do
      App.running_version(release.app, options) == release.version
    else
      false
    end
  end

  defp extracted?(release_dir) do
    File.dir?(release_dir)
  end

  defp path(app, version) do
    "#{app.path}/rel/#{app.name}/releases/#{version}"
  end

  defp release_dir(app, version) do
    "#{app.deploy_path}/releases/#{version}"
  end

  defp tarball(app, version) do
    "#{path(app, version)}/#{app.name}.tar.gz"
  end
end
