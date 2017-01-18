#! /bin/bash


sudo yum install -y epel-release
sudo yum -y install git

# ここからnginx
sudo tee /etc/yum.repos.d/nginx.repo <<EOS >/dev/null
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/7/x86_64
gpgcheck=0
enabled=1
EOS
sudo yum install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx
#sudo firewall-cmd --add-service=http --permanent
#sudo firewall-cmd --reload
sudo mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.back
sudo tee /etc/nginx/conf.d/app.conf <<'EOS' >/dev/null
server {
  listen 80;
  # ドメイン名もしくはipアドレス
  server_name app;
  # プロジェクトのルートディレクトリ
  root /var/www;
  index index.php index.html index.htm;

  # '/'で始まる全てのURIに一致
  location / {
    # リクエストURI, /index.phpの順に処理を試みる
    try_files $uri $uri/ /index.php?$query_string;
  }

  location ~ [^/]\.php(/|$) {
    fastcgi_split_path_info ^(.+\.php)(/.+)$;

    fastcgi_pass unix:/var/run/php-fpm.sock;
    fastcgi_index index.php;
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    fastcgi_param PATH_INFO $fastcgi_path_info;
    fastcgi_param PATH_TRANSLATED $document_root$fastcgi_path_info;
  }
}
EOS
sudo tee -a /etc/nginx/fastcgi_params <<'EOS' >/dev/null

fastcgi_param  SCRIPT_FILENAME         $document_root$fastcgi_script_name;

fastcgi_param   PATH_INFO               $fastcgi_path_info;
fastcgi_param   PATH_TRANSLATED         $document_root$fastcgi_path_info;
EOS
sudo nginx -s reload
sudo mkdir /var/www
test `curl -LI localhost -o /dev/null -w '%{http_code}\n' -s` -eq 502
# ここまでnginx

# ここからphp
export PHPENV_PATH=/opt/phpenv
sudo cp /etc/bashrc_org /etc/bashrc
sudo rm -fr $PHPENV_PATH
curl -L https://raw.github.com/CHH/phpenv/master/bin/phpenv-install.sh | sudo -u vagrant bash
sudo mv /home/vagrant/.phpenv /opt
sudo mv /opt/.phpenv /opt/phpenv
sudo chgrp vagrant /opt/phpenv
sudo git clone https://github.com/php-build/php-build.git /opt/phpenv/plugins/php-build
sudo cp /etc/bashrc /etc/bashrc_org
sudo tee -a /etc/bashrc <<'EOS' >/dev/null
PATH=$PATH:/opt/phpenv/bin
eval "$(phpenv init -)"
EOS
sudo sed -i -e 's|/home/vagrant/.phpenv|/opt/phpenv|g' /opt/phpenv/bin/phpenv
source /etc/bashrc
phpenv -v
sudo yum -y install gcc libxml2-devel bison bison-devel openssl-devel curl-devel libjpeg-devel libpng-devel readline-devel libxslt-devel autoconf automake patch
sudo yum --enablerepo=epel -y install libmcrypt-devel libtidy-devel
sudo yum install -y re2c
sudo yum install -y bzip2
phpenv install 7.0.0
phpenv rehash
phpenv versions
phpenv global 7.0.0
php -v
sudo cp $PHPENV_PATH/versions/7.0.0/etc/php-fpm.conf.default $PHPENV_PATH/versions/7.0.0/etc/php-fpm.conf
sudo sed -i -e "18i pid = /var/run/php-fpm.pid" $PHPENV_PATH/versions/7.0.0/etc/php-fpm.conf
sudo sed -i "s/;events.mechanism = epoll/events.mechanism = epoll/g" $PHPENV_PATH/versions/7.0.0/etc/php-fpm.conf
sudo cp $PHPENV_PATH/versions/7.0.0/etc/php-fpm.d/www.conf.default $PHPENV_PATH/versions/7.0.0/etc/php-fpm.d/www.conf
sudo sed -i "s/user = nobody/;user = nobody/g" $PHPENV_PATH/versions/7.0.0/etc/php-fpm.d/www.conf
sudo sed -i "s/group = nobody/;group = nobody/g" $PHPENV_PATH/versions/7.0.0/etc/php-fpm.d/www.conf
sudo sed -i "25i user = nginx" $PHPENV_PATH/versions/7.0.0/etc/php-fpm.d/www.conf
sudo sed -i "26i group = nginx" $PHPENV_PATH/versions/7.0.0/etc/php-fpm.d/www.conf
sudo sed -i "s/listen = 127.0.0.1:9000/;listen = 127.0.0.1:9000/g" $PHPENV_PATH/versions/7.0.0/etc/php-fpm.d/www.conf
sudo sed -i "39i listen = /var/run/php-fpm.sock" $PHPENV_PATH/versions/7.0.0/etc/php-fpm.d/www.conf
sudo sed -i "40i listen.owner = nginx" $PHPENV_PATH/versions/7.0.0/etc/php-fpm.d/www.conf
sudo sed -i "41i listen.group = nginx" $PHPENV_PATH/versions/7.0.0/etc/php-fpm.d/www.conf
sudo cp /tmp/php-build/source/7.0.0/sapi/fpm/php-fpm.service.in /etc/systemd/system/php-fpm.service
sudo sed -i "`grep -n '\[Service\]' /etc/systemd/system/php-fpm.service | cut -d: -f1`,$(expr $(tail -n $(expr `wc -l /etc/systemd/system/php-fpm.service | cut -d' ' -f1` - `grep -n '\[Service\]' /etc/systemd/system/php-fpm.service | cut -d: -f1`) /etc/systemd/system/php-fpm.service | grep -n '^$' | head -1 | cut -d: -f1) + `grep -n '\[Service\]' /etc/systemd/system/php-fpm.service | cut -d: -f1`)d" /etc/systemd/system/php-fpm.service
sudo tee -a /etc/systemd/system/php-fpm.service <<'EOS' >/dev/null
[Service]
Type=simple
PIDFile=/var/run/php-fpm.pid
ExecStart=/opt/phpenv/versions/7.0.0/sbin/php-fpm --nodaemonize --fpm-config /opt/phpenv/versions/7.0.0/etc/php-fpm.conf
ExecReload=/bin/kill -USR2 $MAINPID
EOS
sudo systemctl start php-fpm
sudo systemctl enable php-fpm
sudo nginx -s reload
test `curl -LI localhost -o /dev/null -w '%{http_code}\n' -s` -eq 200
sudo cd ~
# ここまでphp

# 不要ファイル削除
sudo yum clean all
sudo dd if=/dev/zero of=/zero bs=1M
sudo rm -f /zero
sudo find /var/log/ -type f -name \* -exec cp -f /dev/null {} \;
sudo rm -fr /tmp/*
sudo rm ~/.bash_history
