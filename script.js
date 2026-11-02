let clubs=[],players=[],matches=[],preds=[],muas=[],model=null,thong={ban:[],kt:[],the:[]},mua={id:"",ten:""},curView="bxh";
const C=id=>clubs.find(c=>c.id===id);
const kq=(h,a)=>h>a?"Thắng nhà":h<a?"Thắng khách":"Hòa";
// Danh sách mã CLB (có thể lặp liên tiếp) -> "A → B"
const chain=ids=>ids.filter((v,i)=>v!==ids[i-1]).map(id=>C(id).ten).join(" → ");
const dudoan=p=>{const mx=Math.max(...p);return p[0]===mx&&p[0]>p[1]&&p[0]>p[2]?"Thắng nhà":p[2]===mx&&p[2]>p[0]&&p[2]>p[1]?"Thắng khách":p[1]===mx&&p[1]>p[0]&&p[1]>p[2]?"Hòa":null};
const rounds=()=>[...new Set(matches.map(m=>m[0]))];
const curRound=()=>{const r=rounds();return r.find(v=>matches.some(m=>m[0]===v&&m[3]===null))||r[r.length-1]};

function standings(){
 const t={};clubs.forEach(c=>t[c.id]={id:c.id,tr:0,t:0,h:0,b:0,gf:0,ga:0,sh:0,sa:0,f:[]});
 matches.filter(m=>m[3]!==null).forEach(([,h,a,gh,ga])=>{
  const H=t[h],A=t[a];H.tr++;A.tr++;H.gf+=gh;H.ga+=ga;A.gf+=ga;A.ga+=gh;H.sh+=gh;A.sa+=ga;
  if(gh>ga){H.t++;A.b++;H.f.push("T");A.f.push("B")}else if(gh<ga){A.t++;H.b++;A.f.push("T");H.f.push("B")}else{H.h++;A.h++;H.f.push("H");A.f.push("H")}});
 return Object.values(t).map(x=>({...x,d:x.gf-x.ga,pts:x.t*3+x.h})).sort((a,b)=>b.pts-a.pts||b.d-a.d||b.gf-a.gf);
}

// Một dòng thống kê phong độ (bảng ThongKePhongDo) của một đội trước trận
const formLine=(ten,f)=>f?`<span>${ten}: <b>${f.w}/5</b> thắng · ghi ${f.gf.toFixed(1)} · thủng ${f.ga.toFixed(1)} · nghỉ ${f.nghi} ngày</span>`:`<span>${ten}: chưa có thống kê</span>`;

function aiItem(m,p){
 const d=m[3]!==null,dd=p.p?dudoan(p.p):null,dung=d&&dd?dd===kq(m[3],m[4]):null;
 return `<div style="padding:10px 0;border-bottom:1px solid var(--bd)"><div class="mt" style="border:0;padding:0 0 6px"><span>${C(m[1]).ten} vs ${C(m[2]).ten} <span class="mut">· ${m[5]}</span></span>
 ${d?`<b>${m[3]}-${m[4]} · ${kq(m[3],m[4])}${dung===null?"":dung?" ✓":" ✗"}</b>`:`<span class="tag">Chưa diễn ra</span>`}</div>
 ${p.p?`<div class="bar"><i style="width:${p.p[0]}%;background:#00d775"></i><i style="width:${p.p[1]}%;background:#b9a3c2"></i><i style="width:${p.p[2]}%;background:#e90052"></i></div>
 <div class="leg"><span>Nhà ${p.p[0]}%</span><span>Hòa ${p.p[1]}%</span><span>Khách ${p.p[2]}%</span>${p.n>1?`<span>(đã chạy ${p.n} lần, hiển thị lần mới nhất)</span>`:""}</div>`:`<div class="mut">Chưa có dự đoán cho trận này.</div>`}
 <div class="leg">${formLine(C(m[1]).ten,p.th)}${formLine(C(m[2]).ten,p.tk)}</div></div>`;
}

const views={
bxh(){
 const s=standings(),avg=s.reduce((a,x)=>a+x.pts,0)/s.length;
 const daDa=matches.filter(m=>m[3]!==null).length,xong=daDa===matches.length&&matches.length>0;
 return `<div class="card"><h2>Bảng xếp hạng mùa ${mua.ten} <span class="tag">${xong?"Đã kết thúc":`Đang diễn ra · ${daDa}/${matches.length} trận`}</span></h2><div class="tbl"><table>
 <tr><th>#</th><th>CLB</th><th>Trận</th><th>T</th><th>H</th><th>B</th><th>BT</th><th>BB</th><th>HS</th><th>Điểm</th><th>Phong độ</th></tr>
 ${s.map((x,i)=>`<tr class="${i==0?'champ':i>=s.length-3?'rel':''}"><td>${i+1}</td><td><span class="crest">${C(x.id).ten.slice(0,3).toUpperCase()}</span>${C(x.id).ten}</td><td>${x.tr}</td><td>${x.t}</td><td>${x.h}</td><td>${x.b}</td><td>${x.gf}</td><td>${x.ga}</td><td>${x.d>0?'+':''}${x.d}</td><td><b>${x.pts}</b></td><td class="form">${x.f.slice(-5).map(v=>`<i class="${v}">${v}</i>`).join("")}</td></tr>`).join("")}
 </table></div><p class="mut">${xong?`Vô địch: <b>${C(s[0].id).ten}</b> · Xuống hạng: <b>${s.slice(-3).map(x=>C(x.id).ten).join(", ")}</b>.`:`Hàng đầu: đang dẫn đầu · 3 hàng cuối (vạch đỏ): đang trong vùng xuống hạng.`}
 Điểm trung bình toàn giải: ${avg.toFixed(1)}. CLB trên mức trung bình: ${s.filter(x=>x.pts>avg).map(x=>C(x.id).ten).join(", ")}.</p></div>`;
},
lich(){
 return `<div class="card"><h2>Lịch thi đấu</h2><div class="row">
 <select id="fr"><option value="0">Tất cả vòng</option>${rounds().map(r=>`<option value="${r}"${r===curRound()?" selected":""}>Vòng ${r}</option>`).join("")}</select>
 <select id="fc"><option value="">Tất cả CLB</option>${clubs.map(c=>`<option value="${c.id}">${c.ten}</option>`).join("")}</select></div>
 <div id="ml"></div></div>`;
},
cauthu(){
 return `<div class="card"><h2>Tra cứu cầu thủ</h2><div class="row">
 <input id="q" placeholder="Tìm theo tên...">
 <select id="vt"><option value="">Mọi vị trí</option>${["Thủ môn","Hậu vệ","Tiền vệ","Tiền đạo"].map(v=>`<option>${v}</option>`).join("")}</select>
 <select id="qt"><option value="">Mọi quốc tịch</option>${[...new Set(players.map(p=>p.qt))].sort().map(v=>`<option>${v}</option>`).join("")}</select></div>
 <div class="tbl"><table id="pt"></table></div></div>
 <div class="card"><h2>Hợp đồng sắp hết hạn (trong 6 tháng tới)</h2><div id="exp"></div></div>`;
},
clb(){
 return `<div class="grid">${clubs.map(c=>`<div class="card"><h2>${c.ten}</h2>
 <div class="mut">Sân nhà</div>${c.san}<div class="mut">Thành phố · Năm thành lập</div>${c.tp} · ${c.nam}
 <div class="mut">HLV trưởng hiện tại</div>${c.hlv}
 ${c.cu.length?`<div class="mut">HLV tiền nhiệm</div>${c.cu.map(h=>`${h.ten} (${h.tu}–${h.den})`).join("<br>")}`:""}
 <div class="mut">Cầu thủ</div>${players.filter(p=>p.clb===c.id).map(p=>p.ten).join(", ")||"—"}</div>`).join("")}</div>`;
},
top(){
 const list=(arr,f)=>arr.map((p,i)=>`<div class="mt"><span>${i+1}. ${p.ten} <span class="mut">${chain(p.clb)}</span></span><b>${f(p)}</b></div>`).join("")||"<p class='mut'>Chưa có dữ liệu.</p>";
 return `<div class="grid"><div class="card"><h2>🥇 Vua phá lưới ${mua.ten}</h2>${list(thong.ban,p=>p.n)}</div>
 <div class="card"><h2>🎯 Vua kiến tạo ${mua.ten}</h2>${list(thong.kt,p=>p.n)}</div>
 <div class="card"><h2>🟨 Từ 5 thẻ vàng ${mua.ten}</h2>${list(thong.the,p=>`${p.n}🟨${p.do?` ${p.do}🟥`:""}`)}<p class="mut">Ngưỡng treo giò: 5 thẻ vàng tích lũy.</p></div></div>`;
},
ai(){
 const all=matches.map((m,i)=>({m,p:preds[i]})),done=all.filter(x=>x.m[3]!==null&&x.p.p&&dudoan(x.p.p));
 const ok=done.filter(({m,p})=>dudoan(p.p)===kq(m[3],m[4])).length,cr=curRound();
 return `<div class="card"><h2>🤖 Dự đoán AI · ${mua.ten}</h2><div class="stat">${done.length?(ok/done.length*100).toFixed(0)+"%":"—"}</div>
 <span class="mut">Tỷ lệ dự đoán đúng (${ok}/${done.length} trận đã đá có dự đoán)</span>
 ${model?`<p class="mut">Mô hình: ${model.ten} · huấn luyện trên ${model.mau} trận (${model.ngay})${model.cv===null?"":` · độ chính xác kiểm tra chéo 5-fold: <b>${model.cv.toFixed(1)}%</b>`}. Đặc trưng: chênh điểm và hiệu số từ đầu mùa, phong độ 5 trận gần nhất, số ngày nghỉ.</p>`:""}</div>
 <div class="card"><div class="row"><select id="ar">${rounds().map(r=>`<option value="${r}"${r===cr?" selected":""}>Vòng ${r}</option>`).join("")}</select></div><div id="al"></div></div>`;
}};
const tabs={bxh:"Bảng xếp hạng",lich:"Lịch thi đấu",cauthu:"Cầu thủ",clb:"Câu lạc bộ",top:"Thống kê",ai:"Dự đoán AI"};

function drawAI(){
 const r=+document.getElementById("ar").value;
 document.getElementById("al").innerHTML=matches.map((m,i)=>m[0]===r?aiItem(m,preds[i]):"").join("");
}
function drawMatches(){
 const r=+document.getElementById("fr").value,c=document.getElementById("fc").value;
 const l=matches.filter(m=>(!r||m[0]===r)&&(!c||m[1]===c||m[2]===c));
 document.getElementById("ml").innerHTML=l.map(m=>`<div class="mt"><span style="flex:1;text-align:right">${C(m[1]).ten}</span><b>${m[3]===null?"vs":m[3]+" - "+m[4]}</b><span style="flex:1">${C(m[2]).ten}</span><span class="mut">V${m[0]} · ${m[5]}</span></div>`).join("")||"<p class='mut'>Không có trận nào.</p>";
}
function drawPlayers(){
 const q=document.getElementById("q").value.toLowerCase(),v=document.getElementById("vt").value,n=document.getElementById("qt").value;
 const l=players.filter(p=>p.ten.toLowerCase().includes(q)&&(!v||p.vt===v)&&(!n||p.qt===n));
 document.getElementById("pt").innerHTML=`<tr><th>#</th><th>Cầu thủ</th><th>Quốc tịch</th><th>Vị trí</th><th>CLB hiện tại</th><th>Ngày sinh</th><th>Lịch sử CLB</th></tr>`+l.map((p,i)=>`<tr><td>${i+1}</td><td>${p.ten}</td><td>${p.qt}</td><td>${p.vt}</td><td>${C(p.clb).ten}</td><td>${p.sn}</td><td style="text-align:left">${p.ls.length>1?`<span class="mut">${p.ls.map(h=>`${C(h[0]).ten} (${h[1]})`).join(" → ")}</span>`:`<span class="mut">—</span>`}</td></tr>`).join("");
 const now=new Date(),lim=new Date(now);lim.setMonth(lim.getMonth()+6);
 const e=players.filter(p=>{const d=new Date(p.hh);return d>=now&&d<=lim}).sort((a,b)=>a.hh<b.hh?-1:1);
 document.getElementById("exp").innerHTML=e.map(p=>`<div class="mt"><span>${p.ten} <span class="mut">${C(p.clb).ten}</span></span><b>${p.hh}</b></div>`).join("")||"<p class='mut'>Không có hợp đồng nào.</p>";
}
function tick(){
 const cur=curRound();
 document.getElementById("tick").innerHTML=`<div class="tk-h">Vòng ${cur}</div>`+matches.filter(m=>m[0]===cur).map(m=>`<div class="tk"><small>${m[5]}</small><div><span>${C(m[1]).ten}</span><b>${m[3]===null?"–":m[3]}</b></div><div><span>${C(m[2]).ten}</span><b>${m[4]===null?"–":m[4]}</b></div></div>`).join("");
}
function show(k){
 curView=k;
 document.getElementById("view").innerHTML=views[k]();
 document.querySelectorAll("#nav button").forEach(b=>b.classList.toggle("on",b.dataset.k===k));
 if(k==="lich"){drawMatches();["fr","fc"].forEach(i=>document.getElementById(i).onchange=drawMatches)}
 if(k==="cauthu"){drawPlayers();["q","vt","qt"].forEach(i=>document.getElementById(i).oninput=drawPlayers)}
 if(k==="ai"){drawAI();document.getElementById("ar").onchange=drawAI}
}
document.getElementById("nav").innerHTML=Object.entries(tabs).map(([k,v])=>`<button data-k="${k}">${v}</button>`).join("");
document.getElementById("nav").onclick=e=>{if(e.target.dataset.k)show(e.target.dataset.k)};

function load(id){
 return fetch("api.php"+(id?"?mua="+encodeURIComponent(id):"")).then(r=>r.json()).then(d=>{
  if(d.error)throw new Error(d.error);
  ({mua,muas,clubs,players,matches,preds}=d);thong=d.top;model=d.model;
  const ms=document.getElementById("ms");
  ms.innerHTML=muas.map(m=>`<option value="${m.id}"${m.id===mua.id?" selected":""}>Mùa ${m.ten}</option>`).join("");
  show(curView);tick();
 }).catch(e=>{document.getElementById("view").innerHTML=`<div class="card"><h2>Không tải được dữ liệu</h2><p class="mut">${e.message}. Hãy chạy qua web server (XAMPP: http://localhost/...) và kiểm tra cấu hình CSDL trong api.php.</p></div>`});
}
document.getElementById("ms").onchange=e=>load(e.target.value);
load("");
