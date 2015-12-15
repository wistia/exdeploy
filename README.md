# Exdeploy

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

## Usage

It's expected that you `git clone` this repo onto a box which has Elixir
installed.

Get exdeploy:

    git clone https://github.com/wistia/exdeploy.git
    cd exdeploy

To compile and make a release:

    mix run -e "Exdeploy.Project.build(\"/my/project/path\", \"/the/deploy/path\")"

To upgrade to the latest release:

    mix run -e "Exdeploy.Project.deploy(\"/my/project/path\", \"/the/deploy/path\")"

When upgrading, the deploy path must exist or the deployment will fail.

## Running tests

First fetch deps, compile, and cache releases for our test projects:

    sh setup_test_projects.sh

Then the standard:

    mix test
