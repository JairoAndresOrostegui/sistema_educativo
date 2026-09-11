// QA default. The environment build tool replaces this in build/web-prod only.
// Never allow the QA worker to run on a production origin.
if (['liceobilinguerodolfollinas.edu.co', 'www.liceobilinguerodolfollinas.edu.co',
  'sistema-educativo-rl-prod.web.app', 'sistema-educativo-rl-prod.firebaseapp.com']
  .includes(self.location.hostname)) {
  throw new Error('Worker QA bloqueado en producción. Reconstruye con tools/build_web.js.');
}
self.firebaseRuntime = {
  apiKey: 'AIzaSyBjfpuzVCTvKEMdYGYjMa619SSJ1yL8Jho',
  authDomain: 'sistema-educativo-rl.firebaseapp.com',
  projectId: 'sistema-educativo-rl',
  storageBucket: 'sistema-educativo-rl.firebasestorage.app',
  messagingSenderId: '732639994966',
  appId: '1:732639994966:web:f71afd170b50235fe847f7',
};
