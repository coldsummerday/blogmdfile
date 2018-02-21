
实现效果图:

![](http://orh99zlhi.bkt.clouddn.com/2018-02-11,22:20:45.jpg)

像图中一样 每个评论占一楼,如果是属于某个评论的子评论,该评论会在父评论的楼下进行缩进.



##一、django后台递归实现:
实现原理:获取到一篇文章的所有评论,然后取出所有无父评论的评论节点 (这是最高一层,不需要缩进的节点).然后做一个嵌套字典,key为该父评论,value为一个字典,字典的内容key:子评论,value:子评论的孩子节点的字典.


###一.1  model的设计:

在设计评论的时候需要把父评论的信息记录下来:
所以需要一个指向自身表的外键pid代表了父亲评论.(需要设置可空)

```python
class Comment(models.Model):
    content = models.TextField(verbose_name='评论内容')
    username = models.CharField(max_length=30, blank=True, null=True, verbose_name='用户名')
    email = models.EmailField(max_length=50, blank=True, null=True, verbose_name='邮箱地址')
   
    date_publish = models.DateTimeField(auto_now_add=True, verbose_name='发布时间')

    article = models.ForeignKey(Article, blank=True, null=True, verbose_name='文章',on_delete=models.CASCADE)
    pid = models.ForeignKey('self', blank=True, null=True, verbose_name='父级评论',on_delete=models.CASCADE)
```





###一.2 views后端的设计


```python
def get_comment_dic(request,articleid):
    
    article = Article.objects.get(pk =articleid)
    comments = Comment.objects.filter(article=article).order_by('id')
    #获取评论的父子关系
    comment_tree = {}
    for comment in comments:
        if comment.pid == None:
            #如果该评论没父亲,则给该评论建一个空字典,以备放入该评论的子评论
            comment_tree[comment] = {}
        else:
            #如果该评论有父亲,则需要把该评论插入到它的父评论的字典中,在最顶层寻找它的父亲节点
            find_parent_comment(comment_tree,comment)
    return render(request,'commentlist.html',{'comment_tree':comment_tree})
def find_parent_comment(commentTree,commentObj):
    #在commentTree的最顶层寻找commentObj的父亲评论
    for p,v in commentTree.items():
        if p.id == commentObj.pid.id:
            #如果找到.则插入父亲评论的字典中,key为评论本身,value为该评论的字典,代表了该字典是否有子评论
            commentTree[p][commentObj]={}
        else:
            #如果在该层找不到,就递归深度搜索下一层
            find_parent_comment(commentTree[p],commentObj)
            
            
            
            
            

```

像图中的评论
![](http://orh99zlhi.bkt.clouddn.com/2018-02-11,22:20:45.jpg)

实际传过去的字典为:

```python
In [2]: get_comment_dic(25)
Out[2]: {<Comment: 评论一>: {<Comment: 评论一.1>: {}}, <Comment: 评论二>: {}}
```


我们只是实现了一个代表了评论父子关系的字典,我们需要把该字典还原成层式评论的模样.


###一.3 利用自定义过滤器实现层级评论


首先,我的评论html格式为:

* 无父评论的评论(顶级评论):

```html
<li class="item clearfix" style="margin-left: 5px;"> 
   <div class="comment-main"> 
    <header class="comment-header"> 
     <div class="comment-meta"> 
      <a class="comment-author" href="mailto:%s">评论作者</a> 评论于 
      <time >时间</time> 
     </div> 
    </header> 
    <div class="comment-body"> 
     <p> 评论内容<button type="button" class="btn btn-info" style="float: right;" onclick="回复评论的js方法">回复他/她</button></p> 
    </div> 
   </div> </li>
```


子评论的html

```html
<li class="item clearfix" style="margin-left: 父亲节点的距离+间隔px;">
        <div class="comment-main">
         <header class="comment-header">
          <div class="comment-meta">
           <a class="comment-author" href="mailto:%s">评论作者邮箱</a> 评论于
           <time >%s</time>
          </div>
         </header>
         <div class="comment-body">
          <p><a href="mailto:%s">@父节点作者</a> 评论内容
          <button type="button" class="btn btn-info"
           style="float: right;" onclick=" opencomment('%s')">回复他/她</button></p>
         </div>
        </div> </li>
```


非顶级评论的html格式区别在于:

* margin-left 该属性是 父亲节点margin-left 属性的加某个值,使得视觉上子评论在父亲节点的下面且靠右一点位置.
* 子评论在评论内容中多了@父节点作者


其实树形评论的关键在于,子节点要在相应的父节点文件树下,且有一定的缩进.
用margin-left实现缩进..



由于在template中传入字典并用递归构造出层级评论较麻烦,我们将使用自定义标签的方法,将传入的字典 拼接成html代码,然后返回



一:在appname的目录下建立templatetags目录,并在目录下新建__init__.py空文件,(代表了我们自定义tag的目录)

二、在templatetags目录下新建blog_tags.py文件,代表了自定义标签的真正实现代码:


```python
# -*- coding: utf-8 -*-
from django import template

#注册器
register = template.Library()
```


```python
##基本评论缩减长度
indent_base = 30


##评论,递归建立子评论的html并拼接到原来的html中,相当于将一个评论放在上一个评论的下面,是否父子评论关系由margin-left决定
def recursive_build_tree(html_ele,tree,indent):
    for k,v in tree.items():
        row = '''<li class="item clearfix" style="margin-left: %spx;">
        <div class="comment-main">
         <header class="comment-header">
          <div class="comment-meta">
           <a class="comment-author" href="mailto:%s">%s</a> 评论于
           <time >%s</time>
          </div>
         </header>
         <div class="comment-body">
          <p><a href="mailto:%s">@%s</a> %s
          <button type="button" class="btn btn-info"
           style="float: right;" onclick=" opencomment('%s')">回复他/她</button></p>
         </div>
        </div> </li>
        ''' % (indent, k.email, k.username, \
               k.date_publish.strftime('%Y-%m-%d'), \
               k.pid.email, k.pid.username, k.content,k.id)

        html_ele += row
        if v:
            ##如果子评论的{}不为空,证明子评论还有子评论~需要先将孩子评论插入完才能插入新的顶级评论
            html_ele =  recursive_build_tree(html_ele,tree[k],indent+indent_base)

    return html_ele


#用注释器的方式 注册tag
@register.simple_tag
def build_comment_tree(comment_tree):
    html_ele = "";
    for k,v in comment_tree.items():
        row = '''<li class="item clearfix" style="margin-left: 5px;"> 
   <div class="comment-main"> 
    <header class="comment-header"> 
     <div class="comment-meta"> 
      <a class="comment-author" href="mailto:%s">%s</a> 评论于 
      <time >%s</time> 
     </div> 
    </header> 
    <div class="comment-body"> 
     <p> %s<button type="button" class="btn btn-info" style="float: right;" onclick=" opencomment('%s')">回复他/她</button></p> 
    </div> 
   </div> </li>
            ''' %(k.email,k.username,k.date_publish.strftime('%Y-%m-%d'),k.content,k.id)
        html_ele += row
        if len(v.items())>1:
            html_ele = recursive_build_tree(html_ele,v,indent_base)
    return html_ele +''
```



###一.4 在template模板中使用该标签


```html
        {{ comment_tree | build_comment_tree  }}

```
这样就会将comment_tree作为参数传自定义tag 方法build_comment_tree中,并递归拼接html代码返回


这样就用django后台的方式实现了层级评论..



##二、利用js在前端动态加DOM实现层级评论

像一种在django使用递归太费服务器资源了,正确的做法是把该文章的所有评论信息传到前端,然后由前端处理.


**注:django 的model在新增数据的时候Id的递增的,所以,父节点的ID肯定比子节点id小,所以肯定是父节点插入顺序比它的子节点早**


```javascript
var index_base = 30;
function addcomment(id,name,email,date,content,parentid,parentName,parentEmail){
	var liElement =  document.createElement('li');
	liElement.id = 'comemnt:' + id.toString();
	liElement.className = 'item clearfix';
	liElement.setAttribute('style','margin-left: '+index_base+'px;');
	var mainElement = addCommentMain(email,name,date);
	liElement.appendChild(mainElement);
	mainElement.appendChild(addCommentBody(id,parentName,parentEmail,content,parentid));
	var ul = document.getElementsByClassName('commentList')[0]
	if(parentid==null)
	{
		liElement.setAttribute('style','margin-left: '+index_base+'px;');

		ul.appendChild(liElement);
	}
	else{

		//插入到父评论DOM后面一个DOM的前面
		var beforeElement =  document.getElementById('comemnt:'+parentid.toString());
		var index_before = Number(beforeElement.style.marginLeft.split('px')[0]);
		var index = index_before + index_base;
		liElement.setAttribute('style','margin-left: '+index.toString()+'px;');
		ul.insertBefore(liElement,beforeElement.nextSibling)
	}


}
function addCommentMain(email,name,time)
{
	var main = document.createElement('div');
	main.className = 'comment-main';
	var header = document.createElement('div');
	header.className = 'comment-header';
	main.appendChild(header);
	var meta  = document.createElement('div')
	meta.className = 'comment-meta';
	header.appendChild(meta);
	meta.innerHTML = '<a class="comment-author" href="mailto:' + email + '">' + name +'</a> 评论于 <time >' + time +'</time> '

	return main;
}
function addCommentBody(id,pidName,pidEmail,content,pid)
{
	var bodyElement = document.createElement('div');
	bodyElement.className = 'comment-body';
	var pElement = document.createElement('p');
	bodyElement.appendChild(pElement);
	if(pidName==null)
	{
	pElement.innerHTML ='<p>'+ content +'<button type="button" class="btn btn-info" style="float: right;" onclick="opencomment(\''+id.toString()+'\')">回复他/她</button></p> '
	}
	else
	{
		pElement.innerHTML = '<p><a href="mailto:'+pidEmail+'">@'+pidName+'</a>'+content+'<button type="button" class="btn btn-info"style="float: right;" onclick="opencomment(\''+id.toString()+'\')">回复他/她</button></p>'
	}
	return bodyElement;
}
function build_comment_tree(returndata)
{

	for(var key in returndata)
	{
		var value = returndata[key];
		addcomment(value.id,value.username,value.email,value.date_publish_str,value.content,value.pid_id,value.pid_username,value.pid_email)
	}
}
function ajaxGetComemntList (url) {

$.get(url, function (data, status) {

                if(status=='success')
                {
                    //先删除所有评论再刷新
                    var comment_list_obj = document.getElementsByClassName('commentList')[0]
                    while (comment_list_obj.firstChild)
                    {
                        comment_list_obj.removeChild(comment_list_obj.firstChild);
                    }
                    build_comment_tree(data);
                }


           });
}

```


