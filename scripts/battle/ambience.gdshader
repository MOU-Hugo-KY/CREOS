shader_type canvas_item;
render_mode unshaded;
uniform int effect_kind = 0;
uniform vec4 tint : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform float clock = 0.0;
uniform float phase = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float fbm(vec2 p) { return 0.57*noise(p)+0.28*noise(p*2.07)+0.15*noise(p*4.13); }
void fragment() {
 vec2 p=UV; float t=clock+phase; float a=0.0; vec3 c=tint.rgb;
 if(effect_kind==0) { // flame, rooted at the lower center
  float h=1.0-p.y;
  float wobble=sin(h*7.0-t*5.0)*0.07*h+sin(h*15.0+t*3.0)*0.03;
  float n=fbm(vec2(p.x*5.0,p.y*7.0+t*2.0));
  float width=(0.34*(1.0-h)+0.012)*(0.8+n*0.5);
  a=(1.0-smoothstep(width*0.38,width,abs(p.x-0.5-wobble)))*(1.0-smoothstep(0.63+n*0.3,1.0,h))*smoothstep(0.0,0.1,h);
  c=mix(tint.rgb,vec3(1.0,0.95,0.62),clamp(a*0.7+(1.0-h)*0.3,0.0,1.0));
 } else if(effect_kind==1) { // rising smoke, softened boundaries
  float n=fbm(vec2(p.x*4.0+sin(t*0.4),p.y*5.0+t*0.3));
  vec2 q=p-vec2(0.5+0.10*sin(t*0.5+p.y*4.0),0.5);
  float edge=1.0-smoothstep(0.15,0.5,length(q*vec2(1.15,0.85)));
  a=edge*smoothstep(0.30,0.7,n)*0.48;
 } else if(effect_kind==2) { // restrained horizontal water glints
  float edge=smoothstep(0.0,0.10,p.x)*(1.0-smoothstep(0.90,1.0,p.x))*smoothstep(0.0,0.15,p.y)*(1.0-smoothstep(0.8,1.0,p.y));
  float ripple=sin(p.y*38.0+p.x*3.0-t*1.4+sin(p.x*12.0+t*0.8)*0.7);
  a=smoothstep(0.94,1.0,ripple)*edge*(0.25+0.30*noise(vec2(p.x*18.0+t*0.4,p.y*4.0)));
 } else if(effect_kind==3) { // mist / clouds
  float n=fbm(vec2(p.x*5.0-t*0.12,p.y*3.0));
  float edge=smoothstep(0.0,0.14,p.x)*(1.0-smoothstep(0.86,1.0,p.x))*smoothstep(0.0,0.15,p.y)*(1.0-smoothstep(0.7,1.0,p.y));
  a=edge*smoothstep(0.20,0.8,n)*0.22;
 } else if(effect_kind==4) { // soft light / pulse, no screen sampling
  float r=length((p-0.5)*2.0);a=pow(max(0.0,1.0-r),2.0)*(0.55+0.12*sin(t*2.0)+0.06*sin(t*5.1));
 } else if(effect_kind==5) { // magical filaments
  float edge=smoothstep(0.0,0.12,p.y)*(1.0-smoothstep(0.82,1.0,p.y));
  float curve=0.5+0.20*sin(p.y*7.0+t*0.9)+0.08*sin(p.y*15.0-t*1.3);
  a=(1.0-smoothstep(0.003,0.045,abs(p.x-curve)))*edge*(0.4+0.15*sin(t*1.4+p.y*5.0));
 } else if(effect_kind==6) { // rotating ritual ring
  vec2 q=(p-0.5)*2.0;float r=length(q);float angle=atan(q.y,q.x)+t*0.10;
  float ring=(1.0-smoothstep(0.008,0.032,abs(r-0.72)))+(1.0-smoothstep(0.006,0.018,abs(r-0.90)))*0.5;
  float rune=(1.0-smoothstep(0.0,0.035,abs(sin(angle*12.0))))*(1.0-smoothstep(0.04,0.09,abs(r-0.80)));
  a=clamp(ring+rune,0.0,1.0)*(0.30+0.12*sin(t*1.4));
 }
 COLOR=vec4(c,clamp(a*tint.a*strength,0.0,1.0));
}
