#!/bin/bash

#
# Creates a new Heroku app with the given name and adds required add-ons.
#
# Usage:
# $ ./init.sh <APP-NAME>
#

# Go to bin dir
cd `dirname $0`

# Check we got a valid new name
if [ -z "$1" ]
then
	echo >&2 "Please specify a name (subdomain) for your new Heroku WP app."
	exit 1
fi

if [[ "$1" =~ [^a-z0-9-]+ ]]
then
	echo >&2 "App name '$1' is invalid."
	exit 1
fi

# Check to see if Composer is installed if not install it
type ./composer >/dev/null 2>&1 || ./init-composer.sh || {
	echo >&2 "Composer does not exist and could not be installed."
	exit 1
}

# Check to see if Heroku Toolbelt is installed
type heroku >/dev/null 2>&1 || {
	echo >&2 "Heroku Toolbelt must be installed. (https://toolbelt.heroku.com)"
	exit 1
}

# Check to see if heroku.com is in known_hosts
ssh-keygen -F heroku.com > /dev/null 2>&1
if [ "$?" = 1 ] ; then
  echo "Make an initial SSH connection to heroku.com to add it to known_hosts"
  exit 1
fi

# Create new app and check for success
heroku apps:create "$1" || {
	echo >&2 "Could not create Heroku WP app."
	exit 1
}

# Add Redis Cache
heroku addons:create \
	--app "$1" \
	heroku-redis:hobby-dev

# Add MySQL DB
heroku addons:create \
	--app "$1" \
	--as "CLEARDB_DATABASE" \
	cleardb:ignite

heroku config:set \
	--app "$1" \
	WP_DB_SSL="ON"

# Add SendGrid for email
heroku addons:create \
	--app "$1" \
	sendgrid:starter

# Add New Relic for metrics
heroku addons:create \
	--app "$1" \
	newrelic:wayne

heroku config:set \
	--app "$1" \
	NEW_RELIC_APP_NAME="HerokuWP"

# Set WP salts
type dd >/dev/null

echo "Setting WP salts..."

heroku config:set --app "$1" $( curl -s 'https://api.wordpress.org/secret-key/1.1/salt/' | sed -E -e "s/^define\('(.+)', *'(.+)'\);$/WP_\1=\2/" -e 's/ //g' )

heroku config:set \
	--app "$1" \
	WP_AUTH_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 50 | head -n 1)  \
	WP_SECURE_AUTH_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 50 | head -n 1) \
	WP_LOGGED_IN_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 50 | head -n 1) \
	WP_NONCE_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 50 | head -n 1) \
	WP_AUTH_SALT=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 50 | head -n 1) \
	WP_SECURE_AUTH_SALT=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 50 | head -n 1) \
	WP_LOGGED_IN_SALT=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 50 | head -n 1) \
	WP_NONCE_SALT=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 50 | head -n 1)

echo "Get Salt here: https://api.wordpress.org/secret-key/1.1/salt/"

# Configure Redis Cache
printf "Waiting for Heroku Redis to provision... "
heroku redis:wait \
	--app "$1"
echo "done"

heroku redis:maxmemory \
	--app "$1" \
	--policy volatile-lru
heroku redis:timeout \
	--app "$1" \
	--seconds 60

#
# Do the intial commit for this site
#

# Force heroku git remote to our app
heroku git:remote \
	--app "$1" \
	--ssh-git

# Make initial commit and deploy
true && \
	cd .. && \
	composer update nothing --ignore-platform-reqs -vvv && \
	git add composer.lock && \
	git commit -m "Commit for first deploy '$1'" && \
	git push heroku "nginx-php7"

EXIT_CODE="$?"
if [ "$EXIT_CODE" -ne "0" ]; then
	printf >&2 "\n\nDeploy failed for '$1'.\n\n"
else
	printf "\n\nNew Heroku WP app '$1' created and deployed via:\n\$ git push heroku $1:master\n\n"
fi

heroku addons --app "$1"
heroku redis --app "$1"

exit "$EXIT_CODE"
