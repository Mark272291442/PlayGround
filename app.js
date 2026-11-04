import * as THREE from 'https://esm.sh/three@0.169.0';

const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
const coarsePointer = window.matchMedia('(pointer: coarse)').matches;
const canvas = document.querySelector('#world');
const fallback = document.querySelector('.fallback-glow');
const sections = [...document.querySelectorAll('main .section')];
const revealObserver = new IntersectionObserver((entries) => {
  entries.forEach((entry) => {
    if (entry.isIntersecting) {
      entry.target.classList.add('is-visible');
      revealObserver.unobserve(entry.target);
    }
  });
}, { threshold: 0.13 });
document.querySelectorAll('.reveal').forEach((el) => revealObserver.observe(el));

// A responsive Three.js scene: real geometry, physical materials, dynamic lighting and a light particle field.
let renderer, scene, camera, clock, root;
let scrollY = window.scrollY;
let pointerX = 0, pointerY = 0, targetX = 0, targetY = 0;
let profileGroup, heroGroup, galleryGroup, contactGroup;
let updateAnchors = () => {};
let motionEnabled = !reducedMotion;
const metalObjects = [];

function makeEnvironment() {
  const faces = [];
  const palettes = [
    ['#9ec9ff','#102343'], ['#172b4a','#050a13'], ['#5689ca','#101d37'],
    ['#111b2c','#05070d'], ['#355f91','#111b2d'], ['#08101d','#04060b']
  ];
  palettes.forEach(([top,bottom]) => {
    const face = document.createElement('canvas');
    face.width = 64; face.height = 64;
    const ctx = face.getContext('2d');
    const gradient = ctx.createLinearGradient(0,0,0,64);
    gradient.addColorStop(0,top); gradient.addColorStop(1,bottom);
    ctx.fillStyle = gradient; ctx.fillRect(0,0,64,64);
    ctx.fillStyle = 'rgba(255,255,255,.55)';
    ctx.fillRect(11,10,8,2); ctx.fillRect(42,34,11,2); ctx.fillRect(28,52,5,2);
    faces.push(face);
  });
  const env = new THREE.CubeTexture(faces);
  env.needsUpdate = true;
  env.colorSpace = THREE.SRGBColorSpace;
  return env;
}

function chromeMaterial() {
  return new THREE.MeshStandardMaterial({ color: 0xc9dcf5, metalness: 0.94, roughness: 0.16, envMapIntensity: 1.45 });
}
function blueMetal() {
  return new THREE.MeshStandardMaterial({ color: 0x6593d1, metalness: .83, roughness: .24, envMapIntensity: 1.25, emissive: 0x07162c, emissiveIntensity: .34 });
}
function addMesh(parent, geometry, material, position, scale) {
  const mesh = new THREE.Mesh(geometry, material);
  mesh.position.set(...position);
  if (scale) mesh.scale.set(...scale);
  parent.add(mesh);
  return mesh;
}
function createLabelTexture() {
  const c = document.createElement('canvas'); c.width = 1024; c.height = 256;
  const ctx = c.getContext('2d');
  const grad = ctx.createLinearGradient(0,0,1024,256);
  grad.addColorStop(0,'#101d30'); grad.addColorStop(.48,'#d7e6fb'); grad.addColorStop(.55,'#7896bc'); grad.addColorStop(1,'#111a29');
  ctx.fillStyle = grad; ctx.fillRect(0,0,1024,256);
  ctx.fillStyle = 'rgba(4,10,20,.89)'; ctx.fillRect(12,12,1000,232);
  ctx.strokeStyle = 'rgba(157,195,247,.7)'; ctx.lineWidth = 2; ctx.strokeRect(21,21,982,214);
  ctx.textAlign = 'center'; ctx.fillStyle = '#dceaff'; ctx.font = '500 37px monospace'; ctx.letterSpacing = '11px';
  ctx.fillText('MARVELOUS MARK SANTOS',512,112);
  ctx.fillStyle = '#8ebeff'; ctx.font = '18px monospace'; ctx.letterSpacing = '5px';
  ctx.fillText('CREATIVE DEVELOPER  ·  DIGITAL ARTIST',512,162);
  const texture = new THREE.CanvasTexture(c); texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}
function makeAnchorGroup() {
  const group = new THREE.Group(); scene.add(group); return group;
}

function buildScene() {
  scene = new THREE.Scene();
  scene.background = new THREE.Color('#070b13');
  scene.fog = new THREE.FogExp2('#070b13', .031);
  scene.environment = makeEnvironment();
  camera = new THREE.PerspectiveCamera(39, innerWidth / innerHeight, .1, 90);
  camera.position.set(0,0,10.4);
  renderer = new THREE.WebGLRenderer({ canvas, alpha: false, antialias: !coarsePointer, powerPreference: 'low-power', stencil: false, depth: true });
  const dpr = Math.min(window.devicePixelRatio || 1, coarsePointer ? 1.15 : 1.65);
  renderer.setPixelRatio(dpr);
  renderer.setSize(innerWidth, innerHeight, false);
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.15;
  renderer.shadowMap.enabled = !coarsePointer;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  clock = new THREE.Clock();

  scene.add(new THREE.AmbientLight(0x9bb9e7, .72));
  const key = new THREE.DirectionalLight(0xc8ddff, 2.2); key.position.set(-4,7,9); scene.add(key);
  const rim = new THREE.PointLight(0x267dff, 70, 18, 2); rim.position.set(4,1,1); scene.add(rim);
  const soft = new THREE.PointLight(0x85b8ff, 32, 16, 2); soft.position.set(-5,-1,2); scene.add(soft);
  const groundGlow = new THREE.PointLight(0x164ba0, 42, 20, 2); groundGlow.position.set(0,-5,-3); scene.add(groundGlow);

  root = new THREE.Group(); scene.add(root);
  heroGroup = makeAnchorGroup(); profileGroup = makeAnchorGroup(); galleryGroup = makeAnchorGroup(); contactGroup = makeAnchorGroup();

  // Hero: bevelled metal nameplate, chrome M medallion and animated orbital geometry.
  const plate = new THREE.Group(); plate.position.set(3.0, .48, .15); heroGroup.add(plate);
  const plaque = addMesh(plate, new THREE.BoxGeometry(3.9,.85,.11,4,2,1), chromeMaterial(), [0,0,0]);
  plaque.castShadow = true;
  const label = addMesh(plate, new THREE.PlaneGeometry(3.78,.74), new THREE.MeshBasicMaterial({ map:createLabelTexture(), transparent:false }), [0,0,.061]);
  label.userData.ignoreRaycast = true;
  const emblem = new THREE.Group(); emblem.position.set(3.06,2.1,.2); heroGroup.add(emblem);
  const medallion = addMesh(emblem,new THREE.TorusGeometry(.62,.085,14,80),chromeMaterial(),[0,0,0]); medallion.rotation.x=.32;
  const crest = addMesh(emblem,new THREE.TorusKnotGeometry(.34,.075,96,12,2,3),blueMetal(),[0,0,.04]);
  crest.rotation.set(.45,.2,.3);
  const jewel = addMesh(emblem,new THREE.IcosahedronGeometry(.15,2),new THREE.MeshPhysicalMaterial({color:0x9bc7ff,metalness:.65,roughness:.08,emissive:0x1d60dc,emissiveIntensity:1.6}),[0,0,.13]);
  metalObjects.push({object:emblem, spin:.15, bob:.18, baseY:2.1});
  const rings = new THREE.Group(); rings.position.set(3.05,.48,-.5); heroGroup.add(rings);
  const orbitA = addMesh(rings,new THREE.TorusGeometry(1.67,.012,8,120),new THREE.MeshBasicMaterial({color:0x68a9ff,transparent:true,opacity:.72}),[0,0,0]); orbitA.rotation.set(.7,.3,.2);
  const orbitB = addMesh(rings,new THREE.TorusGeometry(2.05,.008,8,120),new THREE.MeshBasicMaterial({color:0x8dbdff,transparent:true,opacity:.38}),[0,0,-.08]); orbitB.rotation.set(1.1,-.28,.6);
  const ringC = addMesh(rings,new THREE.TorusGeometry(1.25,.018,8,100),new THREE.MeshBasicMaterial({color:0x347be0,transparent:true,opacity:.62}),[0,0,.1]); ringC.rotation.set(.3,1,.4);
  metalObjects.push({object:rings,spin:.07,bob:0,baseY:.48});

  // Scattered, actual 3D forms with lower-cost geometry and soft emissive edges.
  const forms = new THREE.Group(); heroGroup.add(forms);
  const formsList = [
    [new THREE.IcosahedronGeometry(.31,1),[-2.8,1.9,-1.7],.4],
    [new THREE.OctahedronGeometry(.38,0),[5.7,1.5,-1.5],-.45],
    [new THREE.BoxGeometry(.4,.4,.4,1,1,1),[5.3,-1.9,-1.6],.55],
    [new THREE.TorusGeometry(.42,.075,10,48),[-2.2,-2.1,-1.2],.3],
    [new THREE.DodecahedronGeometry(.28,0),[1.1,2.8,-1.5],.4],
    [new THREE.TetrahedronGeometry(.35,0),[6.1,-.3,-2],.2]
  ];
  formsList.forEach(([geo,pos,spin],i)=>{
    const material=i%2?blueMetal():chromeMaterial();
    const mesh=addMesh(forms,geo,material,pos); mesh.rotation.set(i*.3,i*.5,i*.2); mesh.castShadow=true;
    metalObjects.push({object:mesh,spin,bob:.12+(i%3)*.035,baseY:pos[1],phase:i*1.7, parent:forms});
  });
  const energy = addMesh(heroGroup,new THREE.SphereGeometry(.48,24,16),new THREE.MeshPhysicalMaterial({color:0x7dbaff,roughness:.12,metalness:.22,transmission:.25,thickness:.8,emissive:0x0b54c1,emissiveIntensity:1.2}),[5.2,.9,-.1]);
  const energyLight = new THREE.PointLight(0x347eff,10,5); energyLight.position.copy(energy.position); heroGroup.add(energyLight);
  metalObjects.push({object:energy,spin:.18,bob:.16,baseY:.9,phase:1.2});
  const holo = new THREE.Group(); holo.position.set(-2.2,.25,-2.3); heroGroup.add(holo);
  const holoPanel = addMesh(holo,new THREE.PlaneGeometry(1.05,1.65),new THREE.MeshPhysicalMaterial({color:0x438de3,metalness:.5,roughness:.16,transparent:true,opacity:.18,transmission:.38,side:THREE.DoubleSide}),[0,0,0]);
  const holoBorder = new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.BoxGeometry(1.12,1.72,.035)),new THREE.LineBasicMaterial({color:0x75b9ff,transparent:true,opacity:.86})); holo.add(holoBorder);
  const holoText = new THREE.Group();
  for(let i=0;i<5;i++){ const line=addMesh(holoText,new THREE.BoxGeometry(.55-(i%2)*.14,.012,.008),new THREE.MeshBasicMaterial({color:0x83c3ff,transparent:true,opacity:.72}),[-.12,.42-i*.16,.03]); }
  holo.add(holoText); metalObjects.push({object:holo,spin:.06,bob:.08,baseY:.25});

  // Profile scene: a freely floating wireframe halo framing the untouched uploaded portrait in the DOM.
  profileGroup.position.set(2.9,0,-.45);
  const profileHalo = new THREE.Group(); profileHalo.position.set(0,0,-.5); profileGroup.add(profileHalo);
  const halo1=addMesh(profileHalo,new THREE.TorusGeometry(1.85,.012,8,140),new THREE.MeshBasicMaterial({color:0x6eaaff,transparent:true,opacity:.57}),[0,0,0]); halo1.rotation.set(.5,.2,0);
  const halo2=addMesh(profileHalo,new THREE.TorusGeometry(2.1,.009,8,140),new THREE.MeshBasicMaterial({color:0x366fc3,transparent:true,opacity:.46}),[0,0,-.12]); halo2.rotation.set(1,.4,.2);
  const profileSpark=addMesh(profileHalo,new THREE.IcosahedronGeometry(.17,1),chromeMaterial(),[1.7,.75,.2]);
  metalObjects.push({object:profileHalo,spin:-.04,bob:.1,baseY:0});

  // Gallery backdrop: distant architectural ribs and glints, deliberately restrained on small screens.
  galleryGroup.position.set(0,0,-1.7);
  const structure=new THREE.Group(); galleryGroup.add(structure);
  const ribMaterial=new THREE.MeshStandardMaterial({color:0x1d395f,metalness:.76,roughness:.34,emissive:0x07162b,emissiveIntensity:.45});
  for(let i=0;i<7;i++){
    const x=-6.5+i*2.15;
    const rib=addMesh(structure,new THREE.TorusGeometry(1.15,.016,6,64,Math.PI),ribMaterial,[x,-.15,-1.8-Math.abs(3-i)*.3]);
    rib.rotation.z=Math.PI; rib.rotation.y=(i-3)*.04;
  }
  const pedestal=addMesh(galleryGroup,new THREE.TorusGeometry(2.4,.009,6,128),new THREE.MeshBasicMaterial({color:0x3976bd,transparent:true,opacity:.42}),[0,-2.65,-.3]);
  pedestal.rotation.x=Math.PI/2;

  // Small energy core near the final contact section.
  contactGroup.position.set(0,0,-.6);
  const core=addMesh(contactGroup,new THREE.IcosahedronGeometry(.72,2),new THREE.MeshPhysicalMaterial({color:0x8dbaff,metalness:.5,roughness:.1,emissive:0x1d63d1,emissiveIntensity:1.35}),[0,0,0]);
  const coreWire=addMesh(contactGroup,new THREE.IcosahedronGeometry(.88,1),new THREE.MeshBasicMaterial({color:0x76adff,wireframe:true,transparent:true,opacity:.22}),[0,0,0]);
  const coreRing=addMesh(contactGroup,new THREE.TorusGeometry(1.25,.012,8,100),new THREE.MeshBasicMaterial({color:0x589bfa,transparent:true,opacity:.68}),[0,0,0]);coreRing.rotation.set(.85,.2,.15);
  metalObjects.push({object:core,spin:.25,bob:.12,baseY:0},{object:coreWire,spin:-.12,bob:.12,baseY:0},{object:coreRing,spin:.1,bob:0,baseY:0});

  const mobile = coarsePointer || innerWidth < 700;
  const count = mobile ? 115 : 330;
  const positions=new Float32Array(count*3), speeds=new Float32Array(count), phases=new Float32Array(count);
  for(let i=0;i<count;i++){
    positions[i*3]=(Math.random()-.5)*17;
    positions[i*3+1]=(Math.random()-.5)*13;
    positions[i*3+2]=-5-Math.random()*12;
    speeds[i]=.08+Math.random()*.22; phases[i]=Math.random()*Math.PI*2;
  }
  const particleGeometry=new THREE.BufferGeometry();particleGeometry.setAttribute('position',new THREE.BufferAttribute(positions,3));
  const particles=new THREE.Points(particleGeometry,new THREE.PointsMaterial({color:0x9fc8ff,size:mobile?0.032:0.038,transparent:true,opacity:.7,sizeAttenuation:true,depthWrite:false,blending:THREE.AdditiveBlending}));
  root.add(particles);particles.userData={speeds,phases,positions};

  // Fine architectural light bars add scale without expensive shadows or post-processing.
  const bars=new THREE.Group(); heroGroup.add(bars);
  const barMaterial=new THREE.MeshBasicMaterial({color:0x2d5a91,transparent:true,opacity:.22});
  for(let i=0;i<9;i++){
    const bar=addMesh(bars,new THREE.BoxGeometry(.018,5+Math.random()*3,.018),barMaterial,[-6.3+i*1.55,-.2,-5.5]);
    if(i%2===0)bar.material=barMaterial.clone();
  }

  updateAnchors=()=>{
    const offset=(element)=>element.getBoundingClientRect().top+window.scrollY+element.offsetHeight*.42;
    heroGroup.position.y=0;
    profileGroup.position.y=-offset(document.querySelector('#about'))/400;
    galleryGroup.position.y=-offset(document.querySelector('#work'))/400;
    contactGroup.position.y=-offset(document.querySelector('#contact'))/400;
  };
  updateAnchors();
  return {particles, updateAnchors};
}

let particleField;
try {
  buildScene();
} catch (error) {
  console.warn('3D scene unavailable; using the lightweight background fallback.', error);
  canvas.style.display='none'; fallback.style.zIndex='0';
}

function resize() {
  if(!renderer||!camera)return;
  camera.aspect=innerWidth/innerHeight; camera.updateProjectionMatrix();
  renderer.setPixelRatio(Math.min(window.devicePixelRatio||1,(coarsePointer||innerWidth<700)?1.15:1.65));
  renderer.setSize(innerWidth,innerHeight,false);
}
window.addEventListener('resize',()=>{resize();updateAnchors();});
window.addEventListener('scroll',()=>{scrollY=window.scrollY;},{passive:true});
window.addEventListener('pointermove',(event)=>{
  if(event.pointerType==='touch')return;
  targetX=(event.clientX/innerWidth-.5)*2;
  targetY=(event.clientY/innerHeight-.5)*2;
},{passive:true});
window.addEventListener('pointerdown',(event)=>{
  if(event.pointerType==='touch'){
    targetX=(event.clientX/innerWidth-.5)*1.3;
    targetY=(event.clientY/innerHeight-.5)*1.3;
  }
},{passive:true});

if(renderer){
  const particles=scene.children.find(child=>child.isPoints);
  particleField=particles?.userData;
  let lastTime=0;
  function animate(now=0){
    requestAnimationFrame(animate);
    if(document.hidden)return;
    if(now-lastTime< (coarsePointer?30:16))return;
    lastTime=now;
    const t=clock.getElapsedTime();
    const scrollTarget=-scrollY/400;
    camera.position.y+=(scrollTarget-camera.position.y)*.055;
    pointerX+=(targetX-pointerX)*.045;pointerY+=(targetY-pointerY)*.045;
    camera.position.x+=(pointerX*.32-camera.position.x)*.035;
    camera.position.z+=(10.4+Math.abs(pointerX)*.1-camera.position.z)*.03;
    camera.rotation.x+=(-pointerY*.018-camera.rotation.x)*.035;
    camera.lookAt(pointerX*.2,camera.position.y+pointerY*.12,0);
    if(motionEnabled){
      metalObjects.forEach(({object,spin,bob,baseY,phase=0})=>{
        object.rotation.y+=spin*.009;
        object.rotation.x+=spin*.002;
        object.position.y=baseY+Math.sin(t*.65+phase)*bob;
      });
      if(particleField){
        const {positions,speeds,phases}=particleField;
        for(let i=0;i<speeds.length;i++){
          positions[i*3+1]+=(Math.sin(t*.36+phases[i])*0.0015);
          positions[i*3]+=Math.sin(t*.2+phases[i])*0.0007;
        }
        particles.geometry.attributes.position.needsUpdate=true;
      }
    }
    renderer.render(scene,camera);
  }
  requestAnimationFrame(animate);
}

// A restrained 3D tilt for project cards and subtle depth parallax around the original photo.
if(!coarsePointer&&!reducedMotion){
  document.querySelectorAll('.project-card').forEach((card)=>{
    card.addEventListener('pointermove',(event)=>{
      const rect=card.getBoundingClientRect();const x=(event.clientX-rect.left)/rect.width-.5;const y=(event.clientY-rect.top)/rect.height-.5;
      card.style.transform=`perspective(900px) rotateY(${x*3.2}deg) rotateX(${-y*2.4}deg) translateY(-4px)`;
    });
    card.addEventListener('pointerleave',()=>card.style.transform='');
  });
  const frame=document.querySelector('#portraitFrame');
  frame?.addEventListener('pointermove',(event)=>{
    const r=frame.getBoundingClientRect();const x=(event.clientX-r.left)/r.width-.5;const y=(event.clientY-r.top)/r.height-.5;
    frame.style.transform=`rotateY(${x*5}deg) rotateX(${-y*4}deg)`;
  });
  frame?.addEventListener('pointerleave',()=>frame.style.transform='');
}

const menuButton=document.querySelector('.menu-toggle');
const nav=document.querySelector('.desktop-nav');
menuButton.addEventListener('click',()=>{
  const open=menuButton.getAttribute('aria-expanded')==='true';
  menuButton.setAttribute('aria-expanded',String(!open));menuButton.setAttribute('aria-label',open?'Open menu':'Close menu');nav.classList.toggle('is-open',!open);
});
nav.querySelectorAll('a').forEach(link=>link.addEventListener('click',()=>{menuButton.setAttribute('aria-expanded','false');nav.classList.remove('is-open');}));

const projectInfo={
  'Orbit':{type:'DIGITAL EXPERIENCE · 2025',title:'Orbit — made to move you.',description:'A speculative launch experience built around a singular product idea. A focused visual system, tactile motion and an immersive point of view turn a first look into a small journey.'},
  'Still Form':{type:'BRAND & DIGITAL · 2024',title:'Still Form — less, but better.',description:'An editorial home for considered objects and slower living. Warm materials, confident typography and a calm, responsive layout give every piece a little room to breathe.'},
  'Night Shift':{type:'INTERACTIVE · 2024',title:'Night Shift — sound after dark.',description:'An interactive sound study for the hours after everything gets quiet. Oscillating forms and a late-night palette make listening feel like exploring.'}
};
const modal=document.querySelector('.project-modal');
const closeModal=()=>{modal.classList.remove('is-open');modal.setAttribute('aria-hidden','true');document.body.classList.remove('modal-open');};
function openProject(card){
  const name=card.querySelector('h3').textContent.split(' —')[0];const info=projectInfo[name];if(!info)return;
  const preview=card.querySelector('.project-art').cloneNode(true);preview.removeAttribute('aria-hidden');
  const modalPreview=modal.querySelector('.modal-preview');modalPreview.replaceChildren(preview);
  modal.querySelector('.modal-type').textContent=info.type;
  modal.querySelector('#modal-title').textContent=info.title;
  modal.querySelector('.modal-description').textContent=info.description;
  modal.classList.add('is-open');modal.setAttribute('aria-hidden','false');document.body.classList.add('modal-open');
  modal.querySelector('.modal-close').focus();
}
document.querySelectorAll('.project-card').forEach(card=>{
  card.addEventListener('click',()=>openProject(card));
  card.addEventListener('keydown',(event)=>{if(event.key==='Enter'||event.key===' '){event.preventDefault();openProject(card);}});
});
modal.querySelector('.modal-close').addEventListener('click',closeModal);
modal.querySelector('.modal-backdrop').addEventListener('click',closeModal);
modal.querySelector('.modal-contact').addEventListener('click',closeModal);
window.addEventListener('keydown',(event)=>{if(event.key==='Escape')closeModal();});
