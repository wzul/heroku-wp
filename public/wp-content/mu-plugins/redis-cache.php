<?php // mu-plugins/load.php

/*
Plugin Name: Redis Object Cache
Plugin URI: https://wordpress.org/plugins/redis-cache/
Description: A persistent object cache backend powered by Redis. Supports Predis, PhpRedis, HHVM, replication, clustering and WP-CLI.
Version: 1.3.5
Text Domain: redis-cache
Domain Path: /languages
Author: Till Krüss
Author URI: https://till.im/
License: GPLv3
License URI: http://www.gnu.org/licenses/gpl-3.0.html
*/


require 'redis-cache/redis-cache.php';
