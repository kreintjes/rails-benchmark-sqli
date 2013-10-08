rake db:reset RAILS_ENV=production
rm log/*
rails s -e production
