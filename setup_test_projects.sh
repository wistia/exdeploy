export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export MIX_ENV=prod

setup_cached_releases () {
  echo "Making releases for $1..."
  cd $1

  # clear the existing cache so this is fresh
  rm -rf cached_rel

  # make sure we've got deps
  mix deps.get && mix compile

  # build releases 0.0.1 and 0.0.2
  cp mix-0.0.1.exs mix.exs
  mix release
  cp mix-0.0.2.exs mix.exs
  mix release
  cp mix-0.0.1.exs mix.exs

  # move it to the cache folder (used in our tests)
  mv rel cached_rel
}

setup_cached_releases "$SCRIPT_DIR/test_projects/build/normal_project"
setup_cached_releases "$SCRIPT_DIR/test_projects/umbrella_project/apps/sub_project1"
setup_cached_releases "$SCRIPT_DIR/test_projects/umbrella_project/apps/sub_project2"
