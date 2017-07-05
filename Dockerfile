FROM php:5.6-apache
MAINTAINER Riccardo Manuelli

# Install gd, iconv, mbstring, mcrypt, mysql, soap, sockets, zip, and zlib extensions
# see example at https://hub.docker.com/_/php/
RUN apt-get update && apt-get install -y \
        libbz2-dev \
        libfreetype6-dev \
        libgd-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libpng12-dev \
        libxml2-dev \
        zlib1g-dev \
        groupadd mysql && useradd -g mysql mysql \
        pwgen \
    && docker-php-ext-install iconv mbstring mcrypt soap sockets zip \
    && docker-php-ext-configure gd --enable-gd-native-ttf --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install gd \
    && docker-php-ext-configure mysql --with-mysql=mysqlnd \
    && docker-php-ext-install mysql 
   

# Add a PHP config file. The file was copied from a php53 dotdeb package and
# lightly modified (mostly for improving debugging). This may not be the best
# idea.
COPY php.ini /usr/local/etc/php/

# enable mod_rewrite
RUN a2enmod rewrite

# make the webroot a volume
VOLUME /var/www/html/

# In images building upon this image, copy the src/ directory to the webserver
# root and correct the owner.
ONBUILD COPY src/ /var/www/html/
ONBUILD RUN chown -R www-data:www-data /var/www/html

# support jwilder/nginx-proxy resp. docker-gen
# You may wan to overwrite VIRTUAL_HOST and UPSTREAM_NAME in your Docker file.
EXPOSE 80
ENV VIRTUAL_HOST site.local
ENV UPSTREAM_NAME web-site

# Put something like this into your Dockerfile if you want to add more files.
# Note that you need to correctly set the owner otherwise PHP will not be able
# to edit the file system.
## copy src-extra
#COPY src-extra/ /var/www/html/extra/
#RUN chown -R www-data:www-data /var/www/html/extra


# the "/var/lib/mysql" stuff here is because the mysql-server postinst doesn't have an explicit way to disable the mysql_install_db codepath besides having a database already "configured" (ie, stuff in /var/lib/mysql/mysql)
# also, we set debconf keys to make APT a little quieter
RUN { \
		echo mysql-community-server mysql-community-server/data-dir select ''; \
		echo mysql-community-server mysql-community-server/root-pass password ''; \
		echo mysql-community-server mysql-community-server/re-root-pass password ''; \
		echo mysql-community-server mysql-community-server/remove-test-db select false; \
	} | debconf-set-selections \
	&& apt-get update && apt-get install -y mysql-server && rm -rf /var/lib/apt/lists/* \
	&& rm -rf /var/lib/mysql && mkdir -p /var/lib/mysql /var/run/mysqld \
	&& chown -R mysql:mysql /var/lib/mysql /var/run/mysqld \
# ensure that /var/run/mysqld (used for socket and lock files) is writable regardless of the UID our mysqld instance ends up having at runtime
	&& chmod 777 /var/run/mysqld

# comment out a few problematic configuration values
# don't reverse lookup hostnames, they are usually another container
RUN sed -Ei 's/^(bind-address|log)/#&/' /etc/mysql/mysql.conf.d/mysqld.cnf \
	&& echo '[mysqld]\nskip-host-cache\nskip-name-resolve' > /etc/mysql/conf.d/docker.cnf
	
VOLUME /var/lib/mysql

# Entrypoint file tries to fix permissions, again
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 3306
CMD ["mysqld"]
