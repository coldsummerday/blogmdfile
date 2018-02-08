javascript


##操作浏览器

window 全局域
表示浏览器窗口


```
window.innerWidth //当前窗口宽度
window.innerHeight  //高度
.outerWidth 整个浏览器宽度
```
####screen

screen.width：屏幕宽度，以像素为单位；
screen.height：屏幕高度，以像素为单位；
screen.colorDepth：返回颜色位数，如8、16、24。

####location
location为当前页面的url信息
当url为:http://www.example.com:8080/path/index.html?a=1&b=2#TOP
的时候:

```
location.protocol; // 'http'
location.host; // 'www.example.com'
location.port; // '8080'
location.pathname; // '/path/index.html'
location.search; // '?a=1&b=2'
location.hash; // 'TOP'
```

加载新页面:
**location.assign('新页面地址')**

重新加载此页面:
**location.reload()**

####document 当前页面
HTML在浏览器中以DOM形式表示为树形结构，document对象就是整个DOM树的根节点。

要查找DOM树的某个节点，需要从document对象开始查找。最常用的查找是根据ID和Tag Name。

```
<dl id="drink-menu" style="border:solid 1px #ccc;padding:6px;">
    <dt>摩卡</dt>
    <dd>热摩卡咖啡</dd>
    <dt>酸奶</dt>
    <dd>北京老酸奶</dd>
    <dt>果汁</dt>
    <dd>鲜榨苹果汁</dd>
</dl>
```

```
var menu = document.getElementById('drink-menu');
var drinks = document.getElementsByTagName('dt');
var i, s, menu, drinks;

menu = document.getElementById('drink-menu');
menu.tagName; // 'DL'

drinks = document.getElementsByTagName('dt');
s = '提供的饮料有:';
for (i=0; i<drinks.length; i++) {
    s = s + drinks[i].innerHTML + ',';
}
console.log(s);

```


##操作DOM
###选择获取DOM对象
根据id拿到DOM对象:
document.getElementById()
tagname:
document.getElementsByTagName()
根据document.css选择器:
getElementsByClassName()
####用selector语法获取对象:
querySelector()
querySelectorAll()
低版本IE<8不支持以上

```
// 通过querySelector获取ID为q1的节点：
var q1 = document.querySelector('#q1');

// 通过querySelectorAll获取q1节点内 div.highlighted class内的p元素：
var ps = q1.querySelectorAll('div.highlighted > p');

```

####更新DOM
(1) 改变innerHTML属性

```
// 获取<p id="p-id">...</p>
var p = document.getElementById('p-id');
// 设置文本为abc:
p.innerHTML = 'ABC'; // <p id="p-id">ABC</p>
// 设置HTML:
p.innerHTML = 'ABC <span style="color:red">RED</span> XYZ';
```

(2)改变innerText或者textContent属性:

```
// 获取<p id="p-id">...</p>
var p = document.getElementById('p-id');
// 设置文本:
p.innerText = '<script>alert("Hi")</script>';
// HTML被自动编码，无法设置一个<script>节点:
// <p id="p-id">&lt;script&gt;alert("Hi")&lt;/script&gt;</p>
```

两者的区别在于读取属性时，innerText不返回隐藏元素的文本，而textContent返回所有文本

(3)修改css样式:

```
// 获取<p id="p-id">...</p>
var p = document.getElementById('p-id');
// 设置CSS:
p.style.color = '#ff0000';
p.style.fontSize = '20px';
p.style.paddingTop = '2em';
```

(4)插入DOM:

用Element.appendChild(Element对象)的方式插入对象

```
<!-- HTML结构 -->
<p id="js">JavaScript</p>
<div id="list">
    <p id="java">Java</p>
    <p id="python">Python</p>
    <p id="scheme">Scheme</p>
</div>
```

```
var
    list = document.getElementById('list'),
    haskell = document.createElement('p');
haskell.id = 'haskell';
haskell.innerText = 'Haskell';
list.appendChild(haskell);
```

变成:

```
<!-- HTML结构 -->
<div id="list">
    <p id="java">Java</p>
    <p id="python">Python</p>
    <p id="scheme">Scheme</p>
    <p id="haskell">Haskell</p>
</div>
```

给新创建Element对象增加属性:
var d = document.createElement('style');
d.setAttribute('type', 'text/css');

(4)删除DOM:
要删除一个节点，首先要获得该节点本身以及它的父节点，然后，调用父节点的removeChild把自己删掉：

```
// 拿到待删除节点:
var self = document.getElementById('to-be-removed');
// 拿到父节点:
var parent = self.parentElement;
// 删除:
var removed = parent.removeChild(self);
```


###插入到指定位置:
parentElement.insertBefore(newElement, referenceElement);，子节点会插入到referenceElement之前



##原生ajax:
AJAX请求是异步执行的，也就是说，要通过回调函数获得响应。
在现代浏览器上写AJAX主要依靠XMLHttpRequest对象：

```JavaScript
function success(test){

   
alert(test);
}
function fail(code){
	alert(code)
}


function ajaxtest()
{
	var request;
if (window.XMLHttpRequest) {
    request = new XMLHttpRequest();
} else {
    request = new ActiveXObject('Microsoft.XMLHTTP');
}
	request.onreadystatechange = function(){
		if (request.readyState==4)
		{
			return success(request.responseText);
		}
		else
		{
			return fail(request.status);
		}
	}

	request.open('GET','ajax/more/');
	request.send();
	alert('请求已发送，请等待响应...');
}
```




##备注
javascript不存在返回undefined的特性

获取宽段的时候:
var width = window.innerWidth || document.body.clientWidth;

有时候需要让 a 标签像 button 一样，被点击的时候触发事件而不跳转页面:
让href变执行javascript,并标注onclick 监听函数

```html
<html>
    <body>
        <a id="a1" href="#none" onclick="a_click(this.id)">Click a1</a>
        <a id="a2" href="javascript:void(0);" onclick="a_click(this.id)">Click a2</a>
        <a id="a3" href="any.html" onclick="a_click(this.id);return false;">Click a3</a>
    </body>
    <script type="text/javascript">
        function a_click (aid) {
            alert(aid + " was clicked.");
        }
    </script>
</html>
```


