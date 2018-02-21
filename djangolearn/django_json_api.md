



###一、原生js 的 ajax写法:

* 对于web来说,一次http请求对应一个页面.
* 如果要让用户留在当前页面中，同时发出新的HTTP请求，就必须用JavaScript发送这个新请求，接收到数据后，再用JavaScript更新页面，这样一来，用户就感觉自己仍然停留在当前页面，但是数据却可以不断地更新。
* ajax 是异步执行的,需要回调函数获得响应;



所以其写ajax的步骤:

1. 写好ajax请求成功与失败的回调函数.
2. 创建XMLHttpRequest对象
3. 定义好"GET"或者"POST"方法,并定义访问Url
4. 利用XMLHttpRequest对象的onreadystatechange 来判断状态发生变化,request.readyState === 4时成功完成ajax请求,判断request.status状态码来回调函数



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



###二、django后端:
利用django做rest api(我们只做一个简单的get方法)



* url.py中设置相应的url
* view.py中处理请求,并从model中取出数据
* 将数据序列化
* 返回json文件



```python
#urls.py
path('ajax/more/',more_article),
```

```python
#views.py

#获取请求与处理方法
def more_article(request):
    if request.is_ajax():
        article_list = Article.objects.all()[:5]
        #get_json_objects为我们自己写的从queryset变json的序列化方法
        data = get_json_objects(article_list,Article)
        return HttpResponse(data,content_type="application/json")
    else:
        data = "error"
        
        return HttpResponse(data, content_type="application/json")
        
        
        
        
##自定义序列化方法        
def json_field(field_data):
    if isinstance(field_data,str):
        return "\"" + field_data + "\""
    if isinstance(field_data,bool):
        if field_data == "False":
            return 'false'
        else:
            return 'true'
    return str(field_data)


def json_encode_dict(dict_data):
    json_data = "{"
    for k,v in dict_data.items():
        json_data = json_data + json_field(k) + ": " + json_field(v) + ", "
    json_data = json_data[:-2] + "}"
    return json_data

def json_encode_list(list_data):
    json_res = "["
    for item in list_data:
        json_res  = json_res + json_encode_dict(item) + ", "
    return json_res[:-2] + "]"

def get_json_objects(objects,model_meta):

    list_data = []
    for obj in objects:
        data_dict = {}
        #得到表中每个字段的名字
        for field in model_meta._meta.fields:
            #不需要id
            if field.name == 'id':
                continue
            value = field.value_from_object(obj)
            data_dict[field.name] = value
        list_data.append(data_dict)
    data = json_encode_list(list_data)
    return data

   
```


我们去测试一下这个后台api好用不?

在浏览器输入响应的url:
比如我开发时候是

```
localhost:8000/ajax/more
```

![](http://orh99zlhi.bkt.clouddn.com/2018-02-02,23:08:26.jpg)

测试成功,成功获取到数据



###三、Django-rest-framework
总不能每次都手写序列化与反序列化把?
Django最大的好处是第三方控件多,我们可以利用Django-rest-framework实现

####三.1:序列化:
在app目录下新建**serializers.py**文件,用于序列化功能

针对每个model的序列化:

比如我有一个user类:

```python
class User(AbstractUser):
    profile_photo = models.ImageField(upload_to='photo/%Y/%m',default='photo/default.png',\
                               max_length=200,blank=True, null=True, verbose_name='用户头像')
    qq = models.CharField(max_length=20,blank=True,null=True,verbose_name="QQ号码")
    mobile = models.CharField(max_length=11,blank=True,null=True,unique=True,verbose_name="手机号码")
    url = models.URLField(max_length=100,blank=True,null=True,verbose_name="个人网页地址")
```


最python的写法是继承ModelSerialzer类

```python
class UserSerializer(serializers.ModelSerializer):

    class Meta:
        model = Comment
        fields = (' profile_photo','qq','mobile','url')
```


但是我假如有跨表查询的属性,如article类:

```
class Article(models.Model):
    title = models.CharField(max_length=50,verbose_name='文章标题')
    desc = models.CharField(max_length=50,verbose_name='文章描述')
    content = models.TextField(verbose_name="文章内容")
    click_count = models.IntegerField(default=0,verbose_name='浏览量')
    is_recommend = models.BooleanField(default=False,verbose_name='是否推荐')
    date_publish = models.DateTimeField(auto_now_add=True,verbose_name="发布时间")

    user = models.ForeignKey(User,verbose_name="用户",on_delete=models.CASCADE)
    category = models.ForeignKey(Category,blank=True,null=True,verbose_name="分类",on_delete=models.CASCADE)
    tag = models.ManyToManyField(Tag,verbose_name="标签")
```

我想在序列化的时候,将日期变成我们期望的时间格式,并 统计评论数:

那么,我们需要请出**serializers.SerializerMethodField()**方法,并定义该自定义字段的获取方法,如:

```
class ArticleSerializer(serializers.ModelSerializer):
    #自定义字段
    date_publish_str = serializers.SerializerMethodField()
    comment_count = serializers.SerializerMethodField()
    class Meta:
        model = Article
        #key与model类中属性相同的值直接取数据库中的值
        fields = ('id','title','desc','click_count','date_publish_str','comment_count')


#自定义字段的获取方法,第二个参数传入的为model.object
    def get_comment_count(self,obj):
        return len(obj.comment_set.all())

    def get_date_publish_str(self,obj):
        return obj.date_publish.strftime('%Y-%m-%d')
```


写完serializers.py,我们可以到 **Django shell**中验证自己是否写得正确:

```
In [1]: from blog.models import Article
   ...: from blog.serializers import ArticleSerializer
   ...: from rest_framework.renderers import JSONRenderer
   ...: from rest_framework.parsers import JSONParser
   ...: article = Article.objects.get(title='CV')
   ...: serializer = ArticleSerializer(article)
   ...: serializer.data
```

正是我们想要的结果:

![](http://orh99zlhi.bkt.clouddn.com/2018-02-03,11:26:48.jpg)

#####三.1.1:序列化中的坑:
当自定义字段中,想返回一个None值的时候,不能return "None",
而是直接return;

错误的写法:

```python
    def get_pid_email(self,commentObj):
        if commentObj.pid==None:
            return "None"
        else:
            return commentObj.pid.email
```

正确的写法:

```python
    def get_pid_email(self,commentObj):
        if commentObj.pid==None:
            return
        else:
            return commentObj.pid.email
```

####三.2用序列化来写常规view
#####三.2.1view 请求与相应:
REST框架提供两个装饰器，你可以用它们来写API视图。

* @api_view装饰器用在基于视图的方法上。
* APIView类用在基于视图的类上。 这些装饰器提供一些功能，例如去报在你的视图中接收Request对象，例如在你的Response对象中添加上下文，这样我们就能实现内容通信。 这里装饰器也提供了一些行为，例如在合适的时候返回405 Method Not Allowed响应，例如处理任何在访问错误输入的request.data时出现的解析错误(ParseError)异常

在view中写个get方法的测试:
    
    
```python
#装饰器表示允许的方法
@api_view(['GET'])
def article_index_list(request):
    if request.method == "GET":
        #测试get中假如有tag属性
        if request.GET.get('tag'):
            tagname = request.GET.get('tag')
            try:
                tag_object = Tag.objects.get(name=tagname)
                article_list = tag_object.article_set.all()
            except (Article.DoesNotExist,Tag.DoesNotExist):
                return Response(status.HTTP_404_NOT_FOUND)
            serializer = ArticleSerializer(article_list,many=True)
            return Response(serializer.data)
    return Response(status=status.HTTP_400_BAD_REQUEST)
```

测试结果:

![](http://orh99zlhi.bkt.clouddn.com/2018-02-03,13:51:26.jpg)

如果是想直接返回json数据,可以在get方法中加入format=json
如:
![](http://orh99zlhi.bkt.clouddn.com/2018-02-03,13:52:38.jpg)

#####三.3.2用基于视图的类重写我们的API
用类去继承APIview,然后重写get,post方法(需要实现post就写post,我的博客中不需要实现通过api上传评论,所有只实现了get)

view.py

```python
from rest_framework.views import APIView
class CommentListApi(APIView):

    def get(self,requset,formart=None):
        if requset.GET.get('articleid'):
            articleid = requset.GET.get('articleid')
            try:
                article = Article.objects.get(pk=articleid)
                comments = Comment.objects.filter(article=article).order_by('id')
            except (Article.DoesNotExist,Comment.DoesNotExist):
                return Response("articleid error", status=status.HTTP_400_BAD_REQUEST)
            serializer = CommentSerializer(comments,many=True)
            return Response(serializer.data)
        else:
            return Response("params error", status=status.HTTP_400_BAD_REQUEST)
```

url.py

```python
path('articles/comment-api',CommentListApi.as_view(),name='blog_commentapi'),
```


###三.JQuery 实现前端刷新页面数据

```javascript
//url为访问的api-url
function ajaxGetComemntList (url) {

$.get(url, function (data, status) {

                if(status=='success')
                {
                   
   //data为jquery已经反序列化为js对象
   //成功时候回调的函数
                }


           });
}


```















