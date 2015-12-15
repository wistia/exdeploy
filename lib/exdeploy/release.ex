defmodule Exdeploy.Release do
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

  def install(release) do
    if App.current_version(release.app) == nil do
      IO.puts "#{release.app.name}: Installing a brand new app, starting at version #{release.version}"
      File.mkdir_p(release.app.deploy_path)
      File.cp(release.tarball, "#{release.app.project.deploy_path}/#{release.app.name}.tar.gz")
      System.cmd("tar", ~w[-xf #{release.tarball}], cd: release.app.deploy_path)
      release |> bin "start"
    else
      raise "Can't install #{inspect release};
      Version #{inspect App.current_version(release.app)} is already deployed.
      Try using upgrade or downgrade instead."
    end
  end

  def upgrade(release) do
    if App.current_version(release.app) == nil do
      raise "Can't upgrade #{inspect release};
      No version has been deployed yet. Try using install instead."
    else
      IO.puts "#{release.app.name}: Upgrading from #{App.current_version(release.app)} to #{release.version}"
      IO.puts "copy #{release.tarball} to #{release.release_dir}/#{release.app.name}.tar.gz"
      File.mkdir_p(release.release_dir)
      File.cp(release.tarball, "#{release.release_dir}/#{release.app.name}.tar.gz")
      release |> bin "upgrade #{release.version}"
    end
  end

  def bin(release, cmd) do
    bin = "#{release.app.deploy_path}/bin/#{release.app.name}"
    args = String.split(cmd, " ")
    IO.puts "cd #{release.app.deploy_path} && #{bin} #{cmd}"
    IO.inspect System.cmd(bin, args, cd: release.app.deploy_path)
  end

  defp active_path(app) do
    "#{app.deploy_path}/active"
  end

  def extract(%Release{release_dir: release_dir, tarball: tarball}) do
    unless extracted?(release_dir) do
      IO.puts "Extracting #{tarball} to #{release_dir}"
      File.mkdir_p(release_dir)
      System.cmd("tar", ~w[-xf #{tarball} --directory #{release_dir}])
    end
  end

  def running?(release) do
    if release do
      App.running_version(release.app) == release.version
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
