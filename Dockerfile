FROM rails:4

MAINTAINER bcampbell

RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7
RUN apt-get update && apt-get install -y apt-transport-https ca-certificates
RUN sh -c 'echo deb https://oss-binaries.phusionpassenger.com/apt/passenger trusty main > /etc/apt/sources.list.d/passenger.list'
RUN apt-get update && apt-get install -y libapache2-mod-passenger \
  apache2 python-setuptools augeas-lenses libaugeas0 python-setuptools \
  python-virtualenv apache2-threaded-dev

RUN a2enmod passenger ssl proxy proxy_http
RUN mkdir -p /var/www/phishing-frenzy
WORKDIR /var/www/phishing-frenzy
ADD Gemfile Gemfile.lock ./
RUN bundle install

ADD . /var/www/phishing-frenzy

ADD /pf.conf /etc/apache2/sites-available/pf.conf

RUN a2ensite pf && \
    echo "www-data ALL=(ALL) NOPASSWD: /etc/init.d/apache2 reload" >> /etc/sudoers && \
    chown -R www-data:www-data /etc/apache2/sites-available/ && \
    chown -R www-data:www-data /etc/apache2/sites-enabled/

# Set up final permissions on PF folders
RUN mkdir -p /var/www/phishing-frenzy/tmp/pids && \
    mkdir -p /var/www/phishing-frenzy/log && \
    mkdir -p /var/www/phishing-frenzy/tmp/cache/assets/development && \
    mkdir -p /var/www/phishing-frenzy/tmp/cache/assets/sprockets && \
    mkdir -p /var/www/phishing-frenzy/public/uploads/ && \
    chown -R www-data:www-data /var/www/phishing-frenzy/ && \
    chmod -R 755 /var/www/phishing-frenzy/public/uploads/

# RUN git clone https://github.com/letsencrypt/letsencrypt /opt/letsencrypt

ADD docker_database.yml /var/www/phishing-frenzy/config/database.yml
ADD docker_sidekiq.rb /var/www/phishing-frenzy/config/initializers/sidekiq.rb
EXPOSE 80
EXPOSE 443

CMD [ "/usr/sbin/apache2ctl", "-D", "FOREGROUND" ]
