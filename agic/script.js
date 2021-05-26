import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '5m',  target: 500 }
  ],
};

export default function() {
  // Set your sample app ingress DNS name here
  let res = http.get('https://aspnetappv2.aks.clarenceb.com/',);
  check(res, { 'status was 200': r => r.status == 200 });
  sleep(1);
}
