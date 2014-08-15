module.exports = function() {
  this.After(function (scenario, callback) {
    if (scenario.isFailed()) {
      scenario.attach(create5MegabyteBuffer(), 'text/plain');
    }
    callback();
  });

  function create5MegabyteBuffer() {
    return new Buffer(5 * 1024 * 1024);
  }
};
