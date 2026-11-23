--- browser/extensions/newtab/webpack.system-addon.config.js.orig	2026-11-04 21:25:27 UTC
+++ browser/extensions/newtab/webpack.system-addon.config.js
@@ -68,6 +68,7 @@ const vendorOptimization = {
   minimize: true,
   minimizer: [
     new MinimizerPlugin({
+      parallel: false,
       extractComments: false,
       terserOptions: {
         format: {
