/* -------------------------------------------------------------------
*  Branch CSS by user agent
*  2014.9.10. Toshi Nagata
* ----------------------------------------------------------------- */
(function () {
var ua = navigator.userAgent;
/*  URL of this script; replacing the script name with '*.css' will 
    give the correct URL of the CSS.  */
var scripts = document.getElementsByTagName('script');
var this_script = scripts[scripts.length - 1];
var this_url = this_script.src;
var base_dir;
this_url.match(/(.*)\/\w*\.js$/);
base_dir = RegExp.$1;
if (ua.indexOf('iPhone') > 0 || ua.indexOf('iPod') > 0 || ua.indexOf('Android') > 0) {
  css_name = 'smartphone.css';
} else {
  css_name = 'style.css';
}
document.write('<link href="' + base_dir + '/style.css' + '" type="text/css" rel="stylesheet">');
if (css_name == 'smartphone.css') {
  document.write('<link href="' + base_dir + '/' + css_name + '" type="text/css" rel="stylesheet">');
  document.write('<meta name="viewport" content="width=device-width, target-densitydpi=device-dpi, initial-scale=1, user-scalable=yes">');
}
})();
