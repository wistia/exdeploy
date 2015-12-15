export MIX_ENV=prod
export ROOT_DIR=`echo $PWD`
cd $ROOT_DIR/test_projects/normal_project && mix deps.get && mix compile
cd $ROOT_DIR/test_projects/umbrella_project && mix deps.get && mix compile
