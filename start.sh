rake db:reset RAILS_ENV=production
rm log/*
if [ $# -eq 1 ]; then
  BENCHMARK_MODULES=$1 rails s -e production
else
  rails s -e production
fi
