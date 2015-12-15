defmodule Exdeploy.Project do
  alias Exdeploy.Project
  alias Exdeploy.App
  alias Exdeploy.Release

  defstruct [build_path: nil, deploy_path: nil]

  def new(build_path, deploy_path) do
    %Project{
      build_path: build_path,
      deploy_path: deploy_path,
    }
  end

  def apps(project) do
    if umbrella?(project) do
      umbrella_apps(project)
    else
      [non_umbrella_app(project)]
    end
  end

  def umbrella_apps_path(%Project{build_path: path}) do
    "#{path}/apps"
  end

  def umbrella_apps_paths(project = %Project{}) do
    "#{umbrella_apps_path(project)}/*"
    |> Path.expand
    |> Path.wildcard
  end

  def umbrella?(project = %Project{}) do
    umbrella_apps_path(project) |> File.dir?
  end

  defp umbrella_apps(project) do
    Enum.map umbrella_apps_paths(project), fn(app_path) ->
      [app_name|_] = String.split(app_path, "/") |> Enum.reverse
      %App{
        path: app_path,
        name: app_name,
        project: project,
        deploy_path: "#{project.deploy_path}/#{app_name}",
      }
    end
  end

  defp non_umbrella_app(project) do
    app_path = project.build_path
    [app_name|_] = String.split(app_path, "/") |> Enum.reverse
    %App{
      path: app_path,
      name: app_name,
      project: project,
      deploy_path: "#{project.deploy_path}/#{app_name}"
    }
  end

  def deploy(project) do
    Enum.each apps(project), fn(app) ->
      cond do
        App.never_deployed?(app) ->
          App.latest_release(app) |> Release.install
        App.latest_version(app) > App.current_version(app) ->
          App.latest_release(app) |> Release.upgrade
        true ->
          IO.puts "#{app.name}: No version change, skipping"
      end
    end
  end

  def build(project) do
    apps(project)
    |> Enum.map(&App.full_build/1)
  end

  def clean_rel(project) do
    apps(project)
    |> Enum.map(&App.rm_rel/1)
  end

  def releases(project) do
    apps(project)
    |> Enum.map(&App.releases/1)
    |> List.flatten
  end

  def latest_releases(project) do
    apps(project)
    |> Enum.map(&App.latest_release/1)
  end

  def start(project) do
    apps(project)
    |> Enum.map(&App.start/1)
  end

  def stop(project) do
    apps(project)
    |> Enum.map(&App.stop/1)
  end

  def restart(project) do
    apps(project)
    |> Enum.map(&App.restart/1)
  end

  def running?(project) do
    apps(project)
    |> Enum.any?(&App.running?/1)
  end
end
