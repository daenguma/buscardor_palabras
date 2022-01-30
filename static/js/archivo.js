let regexlist = [
'grant'
,'revoke'
,'"'
,'\\*\\='
,'\\=\\*'
,'index'
,'order'
,'dump'
,'load'
,'backup'
,'restore'
,'@@sqlstatus'
,'holdlock'
,'str_replace'
,'allow_dup_row'
,'exec'
]

// let regexlist = [];

const objColor = {
    warning: 'red',
    caution: 'yellow'
}

let tde = document.querySelectorAll('.td-exp');
let tdr = document.querySelectorAll('.td-reg');
let tdl = document.querySelectorAll('.td-line');
let tr = document.querySelectorAll('.tr-result');

let filtro = document.getElementsByName("filtro");
let opt = document.createElement("option");

const isSelectedFilter = function(elem) {
    location.reload();
}

for(let item in tde){
    let texto = tde[item].innerHTML;
    
    if(texto == undefined){
        texto = 'nada';
    }else{
        texto = tde[item].innerHTML.toLowerCase();
        // regexlist.push(texto);
    }
    

    for(let regex of regexlist){
        if(texto.search(regex) >= 0){
            if(regex === 'grant' || regex === 'exec' || regex === 'index' || regex === 'order'){
                setBGColor(objColor.caution,tr[item]);
            }else{
                setBGColor(objColor.warning,tr[item]);
            }
            
            let reg = new RegExp(regex,"g");
            tdr[item].innerHTML = tdr[item].innerHTML.replace(reg,`<b><i>${regex.replace('\\','')}</i></b>`).replace('\\','');
        }
    }
}


function setBGColor(color, elem) {
    elem.style.backgroundColor = color;
}

function setFilter(){
    const colors = [];
    
    for(let item in tr){
        if(tr[item].style != undefined){
            colors.push(tr[item].style.backgroundColor);
        }
    }

    const unq = colors.filter((item, pos)=>{
        return colors.indexOf(item) === pos;
    });

    for(let item of unq){
        if(item === ""){
            let index = unq.indexOf(item);
            unq.splice(index,1);
        }
    }
    
    for(let color of unq){
        let opt = document.createElement("option");
        opt.value = color;
        opt.innerHTML = color;
        opt.style.backgroundColor = color;
        filtro[0].appendChild(opt);
        opt.onclick = function() {
            for(let itemtr in tr){
                if(tr[itemtr] != undefined){
                    if(opt.value != tr[itemtr].style.backgroundColor){
                        tr[itemtr].style.display = 'none';
                    }
                }
            }
        }
    }

}

setFilter();