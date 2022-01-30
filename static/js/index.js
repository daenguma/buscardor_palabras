let td = document.querySelectorAll('.registro');
let galleta = document.cookie
let $back = document.getElementsByClassName("btn-back");
let $fwd = document.getElementsByClassName("btn-fwd");


for (let b in $back) {
    $back[b].onclick = () => {
        history.back();
    };
}

for (let b in $fwd) {
    $fwd[b].onclick = () => {
        history.forward();
    };
}


function cargar() {

    let data = document.getElementById('result');
    console.log(data.value);
    // for (k in obj){
    //     console.log(obj);
    // }
}

// let tdr = document.querySelectorAll('.td-result');

// for(let exp in tdr){
//     // console.log(tdr[exp].innerHTML);
//     if(tdr[exp].innerHTML. === "*="){
//         tdr[exp].style.backgroundColor = "red";
//     }
// }

// for (let i = 0; i < boton.length; i++){
//     boton[i].addEventListener('click', cargar);
// }




// for (let i = 0; i < boton.length; i++){
//     boton[i].addEventListener('click', getData =>{
//         alert(td[i].innerHTML);
//     });
// }




