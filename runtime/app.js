var express = require('express');
const { exec } = require("child_process")
app = express();

app.get('/', function (req, res) {
  res.send('CPeir helper process\n');
});

app.get('/capacity', function (req,res) {
  exec("./capacity.sh", (error, stdout, stderr) => {
      if (error) {
          console.log(`error: ${error.message}`);
      }
      if (stderr) {
          console.log(`stderr: ${stderr}`);
      }
      console.log(`stdout: ${stdout}`);
      res.send(stdout)
  });
  //res.send();
})

app.get('/check/:objid/:cpver', function (req,res) {
  exec("./check.sh  "+req.params.objid+" "+req.params.cpver, (error, stdout, stderr) => {
      if (error) {
          console.log(`error: ${error.message}`);
      }
      if (stderr) {
          console.log(`stderr: ${stderr}`);
      }
      console.log(`stdout: ${stdout}`);
      res.send(stdout)
  });
  //res.send();
})

app.get('/install/:objid/:cpver', function (req,res) {
  exec("./install.sh  "+req.params.objid+" "+req.params.cpver, (error, stdout, stderr) => {
      if (error) {
          console.log(`error: ${error.message}`);
      }
      if (stderr) {
          console.log(`stderr: ${stderr}`);
      }
      console.log(`stdout: ${stdout}`);
      res.send(stdout)
  });
  //res.send();
})

app.get('/registry', function (req,res) {
  exec("./registry.sh  ", (error, stdout, stderr) => {
      if (error) {
          console.log(`error: ${error.message}`);
      }
      if (stderr) {
          console.log(`stderr: ${stderr}`);
      }
      console.log(`stdout: ${stdout}`);
      res.send(stdout)
  });
  //res.send();
})

app.get('/version', function (req,res) {
  exec("./version.sh  ", (error, stdout, stderr) => {
      if (error) {
          console.log(`error: ${error.message}`);
      }
      if (stderr) {
          console.log(`stderr: ${stderr}`);
      }
      console.log(`stdout: ${stdout}`);
      res.send(stdout)
  });
  //res.send();
})


app.listen(8080, function () {
  console.log('CPeir helper app listening on port 8080!');
});
