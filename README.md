# Exdeploy

[![Build Status](https://travis-ci.org/wistia/exdeploy.svg?branch=master)](https://travis-ci.org/wistia/exdeploy)

[Exrm](https://github.com/bitwalker/exrm) does a great job of creating
standalone packages that can be built once and upgraded/downgraded seamlessly.
But the process of moving the packages into place and installing/upgrading is
left up to the user.

Exdeploy takes a project directory and can automatically deploy the latest
release to a deploy folder of your choosing. If you're making your release on
the same box to which you're deploying, then the entire flow can be managed
with Exdeploy.

## Requirements

Each app must explicitly include exrm in its production deps. For umbrella
projects, that means it must exist in the mix.exs of each individual app.

```elixir
defp deps do
  [{:exrm, github: "bitwalker/exrm", tag: "0.19.9", only: :prod}]
end
```

At this time, umbrella sub-projects _must_ live in `apps`. Technically we could
read this from the `mix.exs` file, and will probably do that in the future.

## Usage

It's expected that you `git clone` this repo onto a box which has Elixir
installed.

### Get exdeploy:

    git clone https://github.com/wistia/exdeploy.git
    cd exdeploy

### To make a release:

    mix run -e "Exdeploy.build(\"project_name\", \"/my/project/path\", user: \"the_user\", group: \"the_group\")"

This will install hex and rebar, fetch deps, compile and make a release with
`MIX_ENV=prod`. The executing user must have read/write access to
`/my/project/path`. After running, if `user` and/or `group` options are
specified, the owner and group of the build folder will be changed to match.

### To upgrade to the latest release:

    mix run -e "Exdeploy.deploy(\"project_name\", \"/my/project/path\", \"/the/deploy/path\", user: \"the_user\", group: \"the_group\", app: \"the_app_name\", env: [{"RUN_ERL_LOG_MAXSIZE", 536870912}, {"RUN_ERL_LOG_GENERATIONS", 4}])"

This will find the latest version of the given app in your project, find the
latest exrm release, move it to the deploy location, and issue an upgrade
command. If no app is specified, then all apps (in an umbrella project) will be
deployed sequentially.

The executing user must have read access to /my/project/path and write access
to /the/deploy/path. When the `user` and/or `group` options are specified,
the owner and group of the deployment release folder will be changed to match,
and any ping/upgrade/start commands will be issued as `user`.

## Running tests

First fetch deps, compile, and cache releases for our test projects:

    sh setup_test_projects.sh

Then the standard:

    mix test
