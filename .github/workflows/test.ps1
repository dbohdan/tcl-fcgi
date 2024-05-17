Import-Module $env:ChocolateyInstall\helpers\chocolateyProfile.psm1
refreshenv

tclsh86t tests/fcgi-nginx.test
