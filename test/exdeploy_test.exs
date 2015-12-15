defmodule ExdeployTest do
  use ExUnit.Case
  alias Exdeploy.Project
  alias Exdeploy.App
  alias Exdeploy.Release

  doctest Exdeploy

  def use_mix_exs_version(app = %App{}, version) do
    File.cp("#{app.path}/mix-#{version}.exs", "#{app.path}/mix.exs")
  end

  def use_mix_exs_version(project = %Project{}, version) do
    Enum.each Project.apps(project), &use_mix_exs_version(&1, version)
  end

  def reset_project_build(project) do
    Project.stop(project)
    Project.clean_rel(project)
    use_mix_exs_version(project, "0.0.1")
  end

  def clear_deploy_folder(test_proj_dir) do
    Path.expand("#{test_proj_dir}/deploy/*")
    |> Path.wildcard
    |> Enum.map(&File.rm_rf/1)
  end

  setup do
    test_proj_dir = "#{System.cwd}/test_projects"
    clear_deploy_folder(test_proj_dir)

    umbrella = Project.new("#{test_proj_dir}/build/umbrella_project", "#{test_proj_dir}/deploy")
    normal = Project.new("#{test_proj_dir}/build/normal_project", "#{test_proj_dir}/deploy")

    reset_project_build(umbrella)
    reset_project_build(normal)

    on_exit {umbrella, normal}, fn ->
      reset_project_build(normal)
      reset_project_build(umbrella)
    end

    {:ok, umbrella: umbrella, normal: normal}
  end

  test "lists all apps in umbrella project", ctx do
    apps = Project.apps(ctx[:umbrella])
    [app1, app2] = apps
    assert app1.name == "sub_project1"
    assert app2.name == "sub_project2"
  end

  test "lists one app in normal project", ctx do
    apps = Project.apps(ctx[:normal])
    [app] = apps
    assert app.name == "normal_project"
  end

  test "deployed? returns false when the app has never been built", ctx do
    [app1, app2] = Project.apps(ctx[:umbrella])
    [app3] = Project.apps(ctx[:normal])
    assert App.deployed?(app1) == false
    assert App.deployed?(app2) == false
    assert App.deployed?(app3) == false
  end

  test "lists all releases in umbrella project", ctx do
    [] = Project.releases(ctx[:umbrella])
    Project.build(ctx[:umbrella])
    [rel1, rel2] = Project.releases(ctx[:umbrella])
    assert rel1.version == "0.0.1"
    assert rel2.version == "0.0.1"
    assert App.deployed?(rel1.app) == false
    assert App.deployed?(rel2.app) == false
  end

  test "lists all releases in normal project", ctx do
    [] = Project.releases(ctx[:normal])
    Project.build(ctx[:normal])
    [rel1] = Project.releases(ctx[:normal])
    assert rel1.version == "0.0.1"
    assert App.deployed?(rel1.app) == false
  end

  test "normal: releases change if mix.exs gets a new version", ctx do
    [] = Project.releases(ctx[:normal])
    Project.build(ctx[:normal])
    [rel1] = Project.releases(ctx[:normal])
    assert rel1.version == "0.0.1"

    use_mix_exs_version(ctx[:normal], "0.0.2")
    Project.build(ctx[:normal])
    [rel1, rel2] = Project.releases(ctx[:normal])
    assert rel1.version == "0.0.1"
    assert rel1.app.name == "normal_project"
    assert rel2.version == "0.0.2"
    assert rel2.app.name == "normal_project"
  end

  test "umbrella: releases change if mix.exs gets a new version", ctx do
    [] = Project.releases(ctx[:umbrella])
    Project.build(ctx[:umbrella])
    [rel1, rel2] = Project.releases(ctx[:umbrella])
    assert rel1.version == "0.0.1"
    assert rel2.version == "0.0.1"

    use_mix_exs_version(ctx[:umbrella], "0.0.2")
    Project.build(ctx[:umbrella])
    [rel1, rel2, rel3, rel4] = Project.releases(ctx[:umbrella])
    assert rel1.version == "0.0.1"
    assert rel1.app.name == "sub_project1"
    assert rel2.version == "0.0.2"
    assert rel2.app.name == "sub_project1"
    assert rel3.version == "0.0.1"
    assert rel3.app.name == "sub_project2"
    assert rel4.version == "0.0.2"
    assert rel4.app.name == "sub_project2"
  end

  test "normal: first deploy starts app, second deploy upgrades", ctx do
    Project.build(ctx[:normal])

    [app] = Project.apps(ctx[:normal])
    assert App.running?(app) == false
    assert App.deployed?(app) == false

    Project.deploy(ctx[:normal])
    assert App.deployed?(app) == true
    assert App.running?(app) == true
    assert App.running_version(app) == "0.0.1"

    Project.deploy(ctx[:normal])
    assert App.deployed?(app) == true
    assert App.running?(app) == true
    assert App.running_version(app) == "0.0.1"

    # build another version - we'll upgrade to it.
    use_mix_exs_version(ctx[:normal], "0.0.2")
    Project.build(ctx[:normal])

    Project.deploy(ctx[:normal])
    assert App.deployed?(app) == true
    assert App.running?(app) == true
    assert App.running_version(app) == "0.0.2"
  end
end
