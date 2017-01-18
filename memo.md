# memo

```bash

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
sudo tee /var/www/phpinfo.php <<'EOS' >/dev/null
<?php var_export($_SERVER); ?>
EOS
test `curl -LI localhost -o /dev/null -w '%{http_code}\n' -s` -eq 502
# ここまでnginx

# ここからphp
sudo curl -L https://raw.github.com/CHH/phpenv/master/bin/phpenv-install.sh | bash
sudo git clone https://github.com/php-build/php-build.git ~/.phpenv/plugins/php-build
sudo tee -a ~/.bash_profile <<'EOS' >/dev/null
PATH=$PATH:$HOME/.phpenv/bin
eval "$(phpenv init -)"
EOS
sudo source ~/.bash_profile
sudo phpenv -v
sudo yum -y install gcc libxml2-devel bison bison-devel openssl-devel curl-devel libjpeg-devel libpng-devel readline-devel libxslt-devel autoconf automake patch
sudo yum --enablerepo=epel -y install libmcrypt-devel libtidy-devel
sudo yum install -y re2c
sudo yum install -y bzip2
sudo phpenv install 7.0.0
sudo phpenv rehash
sudo phpenv versions
sudo phpenv global 7.0.0
sudo php -v
sudo cd ~/.phpenv/versions/7.0.0/etc
sudo cp php-fpm.conf.default php-fpm.conf
sudo sed -i -e "18i pid = /var/run/php-fpm.pid" ~/.phpenv/versions/7.0.0/etc/php-fpm.conf
sudo sed -i "s/;events.mechanism = epoll/events.mechanism = epoll/g" ~/.phpenv/versions/7.0.0/etc/php-fpm.conf
sudo cd ~/.phpenv/versions/7.0.0/etc/php-fpm.d
sudo cp www.conf.default www.conf
sudo sed -i "s/user = nobody/;user = nobody/g" ~/.phpenv/versions/7.0.0/etc/php-fpm.d/www.conf
sudo sed -i "s/group = nobody/;group = nobody/g" ~/.phpenv/versions/7.0.0/etc/php-fpm.d/www.conf
sudo sed -i "25i user = nginx" ~/.phpenv/versions/7.0.0/etc/php-fpm.d/www.conf
sudo sed -i "26i group = nginx" ~/.phpenv/versions/7.0.0/etc/php-fpm.d/www.conf
sudo sed -i "s/listen = 127.0.0.1:9000/;listen = 127.0.0.1:9000/g" ~/.phpenv/versions/7.0.0/etc/php-fpm.d/www.conf
sudo sed -i "39i listen = /var/run/php-fpm.sock" ~/.phpenv/versions/7.0.0/etc/php-fpm.d/www.conf
sudo sed -i "40i listen.owner = nginx" ~/.phpenv/versions/7.0.0/etc/php-fpm.d/www.conf
sudo sed -i "41i listen.group = nginx" ~/.phpenv/versions/7.0.0/etc/php-fpm.d/www.conf
sudo cp /tmp/php-build/source/7.0.0/sapi/fpm/php-fpm.service.in /etc/systemd/system/php-fpm.service
sudo sudo sed -i "`grep -n '\[Service\]' /etc/systemd/system/php-fpm.service | cut -d: -f1`,$(expr $(tail -n $(expr `wc -l /etc/systemd/system/php-fpm.service | cut -d' ' -f1` - `grep -n '\[Service\]' /etc/systemd/system/php-fpm.service | cut -d: -f1`) /etc/systemd/system/php-fpm.service | grep -n '^$' | head -1 | cut -d: -f1) + `grep -n '\[Service\]' /etc/systemd/system/php-fpm.service | cut -d: -f1`)d" /etc/systemd/system/php-fpm.service
sudo tee -a /etc/systemd/system/php-fpm.service <<'EOS' >/dev/null
[Service]
Type=simple
PIDFile=/var/run/php-fpm.pid
ExecStart=/home/vagrant/.phpenv/versions/7.0.0/sbin/php-fpm --nodaemonize --fpm-config /home/vagrant/.phpenv/versions/7.0.0/etc/php-fpm.conf
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
```

## 参考資料

* [Qiita - sudoとヒアドキュメントでファイルを作成する小技](http://qiita.com/mokemokechicken/items/d9b35c29d6ed4d60b63c)
* [nginx.org - nginx: Linux packages](http://nginx.org/en/linux_packages.html#stable)
* [Qiita - CentOS6.xにてnginxの最新版をインストールする手順](http://qiita.com/utano320/items/0c0d9b84a9a28525bcb9)
* [Qiita - ヒアドキュメントの変数エスケープ](http://qiita.com/mofmofneko/items/bf003d14670644dd6197)
* [Qiita - nginx fastcgi_params を include する箇所、割と皆間違ってるよね？](http://qiita.com/kotarella1110/items/f1ad0bb40b84567cea66)
* [github - php-build/php-build](https://github.com/php-build/php-build)
* [noldor's blog - PHP7をCentOS7にインストールする手順](https://blog.noldor.info/php7-on-centos7/)
* [Qiita - RubyOnRailsとPHPを各複数バージョンで同時テストが可能な開発環境をAWSで作る(その3：PHP編)](http://qiita.com/highdrac/items/e6ccb0a1c315f1689b68)
* [k-holyのPHPとか諸々メモ - Vagrant + シェルスクリプトでPHP開発環境をプロビジョニングしてみたメモ](http://k-holy.hatenablog.com/entry/2013/09/05/084237)
* [Qiita - sedでこういう時はどう書く?](http://qiita.com/hirohiro77/items/7fe2f68781c41777e507)
* [Qiita - VagrantでCentOS7にNGINX+PHP-FPM+PHP7の環境構築](http://qiita.com/yanagikouta/items/6c2b0cbd02876e61c71c)
