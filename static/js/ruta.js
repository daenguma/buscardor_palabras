for(let itemA in document.getElementsByTagName('a')){
    document.getElementsByTagName('a')[itemA].onclick = () => {
         document.querySelectorAll('input[type="checkbox"]')[itemA].checked = true;
    }
}