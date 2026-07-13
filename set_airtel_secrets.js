const { execSync } = require('child_process');
const fs = require('fs');
['AIRTEL_CLIENT_ID', 'AIRTEL_CLIENT_SECRET', 'AIRTEL_WEBHOOK_SECRET'].forEach(key => {
  console.log(`Setting ${key}...`);
  fs.writeFileSync('.temp_secret', 'dummy');
  execSync(`firebase functions:secrets:set ${key} --data-file .temp_secret --force`, { stdio: 'inherit' });
});
fs.unlinkSync('.temp_secret');
