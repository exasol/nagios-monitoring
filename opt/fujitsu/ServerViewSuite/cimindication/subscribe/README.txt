ServerView CIM indication subscription registration tool
========================================================

In this directory are two scripts.
	
- fujitsu_server_wsman.pl is a helper script around Perl::Openwsman
  This is called by the other script in case of WS-MAN communications

- svindication_subscribe.pl is the tool to handle subscription
  registrations for ServerView CIM indications

  About usage call svindication_subscribe.pl (without parameter or with -h)