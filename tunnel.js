const fs = require('fs');
const ngrok = require('ngrok');

(async function() {
  const jupyter = `[Jupyter Notebook](${await ngrok.connect(8888)})`;
  console.log(jupyter);
  const tensorboard = `[Tensorboard](${await ngrok.connect(6006)})`;
  console.log(tensorboard);
  fs.writeFileSync("shared/log.md", `${jupyter} | ${tensorboard}`);
})();
