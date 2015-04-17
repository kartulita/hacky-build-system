'use strict';

var gulp = require('gulp');
var jshint = require('gulp-jshint');
var jshintReporter = require('jshint-stylish-source');

var mod = process.env.module || '**';

gulp.task('lint', function () {
	return gulp.src(['src/' + mod + '/*.js', '!**/node_modules/**', '!**/bower_components/**'])
		.pipe(jshint())
		.pipe(jshint.reporter(jshintReporter))
		;
});
