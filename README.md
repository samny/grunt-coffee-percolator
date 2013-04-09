# grunt-percolator-task

Soulwire's CakeFile Percolator ported to grunt task. 

## Getting Started
Install this grunt plugin next to your project's [grunt.js gruntfile][getting_started] with: `npm install grunt-percolator-task`

Then add this line to your project's `grunt.js` gruntfile:

```javascript
grunt.loadNpmTasks('grunt-percolator-task');
```

```javascript

percolator: {
  source: 'path/to/coffee/folder',
  output: 'path/to/js/folder/main.js',
  main: 'main.coffee',
  compile: true,
  opts: '--lint'
}
```

[grunt]: http://gruntjs.com/
[getting_started]: https://github.com/gruntjs/grunt/blob/master/docs/getting_started.md

## Documentation
For usage and documentation, see Soulwire's repo at https://github.com/soulwire/Coffee-Percolator

### Note
Make sure not to set a watch on the folder you are compiling to, this will force a loop.