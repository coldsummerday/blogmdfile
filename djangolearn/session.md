#一:Cookies
###(1)读取cookies
每个**HttpRequest**对象有个**COOKIES**的对象,为一个'字典',可以读取发给view的cookies:

```python
def show_color(request):
    if "favorite_color" in request.COOKIES:
        return HttpResponse("Your favorite color is %s" %             request.COOKIES["favorite_color"])
    else:
        return HttpResponse("You don't have a favorite color.")
```

 request.COOKIES["favorite_color"])则是获取cookies中favorite_color的值.
 
###(2)写入cookies
希尔cookies需要用HttpResponse.set_cookie()的方法:

其参数类似于(key,value)的形式
```python
response = HttpResponse("Your favorite color is now %s" %             request.GET["favorite_color"])
response.set_cookie("favorite_color",
'red')
```

response.set_cookie() 传递一些可选的参数来控制cookie的行为

* max_age  默认None,cookie需要延续的时间（以秒为单位） 
* expires  默认为None,失效日期
* path,"/",cookies生效的网站前缀
* domain , "None",cookie生效的站点


###(3)使用cookies存在问题:

>(1)cookie的存储是自愿的，一个客户端不一定要去接受或存储cookie。 事实上，所有的浏览器都让用户自己控制 是否接受cookies。
>
>(2)Cookie(特别是那些没通过HTTPS传输的)是非常不安全的。 因为HTTP数据是以明文发送的，所以 特别容易受到嗅探攻击。 也就是说，嗅探攻击者可以在网络中拦截并读取cookies，因此你要 绝对避免在cookies中存储敏感信息。 这就意味着您不应该使用cookie来在存储任何敏感信息。
>
>
>
>
>

#二.Sessions
要打开Session功能,确保以下操作:

* 编辑 MIDDLEWARE_CLASSES 配置，确保 MIDDLEWARE_CLASSES 中包含 'django.contrib.sessions.middleware.SessionMiddleware'。
* 确认 INSTALLED_APPS 中有 'django.contrib.sessions' 

###(1)session操作
在view.py中:
    每个传给视图(view)函数的第一个参数**HttpRequest** 对象都有一个 **session** 属性.此属性类似于字典用法:

```python
# 设置session
request.session["fav_color"] = "blue"

#获取session
fav_color = request.session["fav_color"]

#清空session
del request.session["fav_color"]

#查看某值是否在session:
if "fav_color" in request.session:
    ...
```

比如,在用户发表一次评论后将has_commented设置为true,

```python
def post_comment(request):
    if request.method != 'POST':
        raise Http404('Only POSTs are allowed')

    if 'comment' not in request.POST:
        raise Http404('Comment not submitted')

    if request.session.get('has_commented', True):
        return HttpResponse("You've already commented.")

    c = comments.Comment(comment=request.POST['comment'])
    c.save()
    request.session['has_commented'] = True
    return HttpResponse('Thanks for your comment!')
```



比如一个登录后设置 用户id,注销后删除session中Id 的做法:


```python
def login(request):
    if request.method != 'POST':
        raise Http404('Only POSTs are allowed')
    try:
        m = Member.objects.get(username=request.POST['username'])
        if m.password == request.POST['password']:
            request.session['user_id'] = m.id
            return HttpResponseRedirect('/you-are-logged-in/')
    except Member.DoesNotExist:
        return HttpResponse("Your username and password didn't match.")
```

```python
#注销
def logout(request):
    try:
        del request.session['member_id']
    except KeyError:
        pass
    return HttpResponse("You're logged out.")
```

###(2)设置测试Cookies
不能指望所有的浏览器都可以接受cookie。 因此，为了使用方便，Django提供了一个简单的方法来测试用户的浏览器是否接受cookie

**set_test_cookie()**
**test_cookie_worked()**

工作 原理:
>在每次回应中添加测试cookie的值,当下次浏览器请求的时候,检查该请求是否带上test的cookie的值,若,带上,证明cookie可用


虽然把 set_test_cookie() 和 test_cookie_worked() 分开的做法看起来有些笨拙，但由于cookie的工作方式，这无可避免。 当设置一个cookie时候，只能等浏览器下次访问的时候，你才能知道浏览器是否接受cookie。

```python
def login(request):
    if request.method == 'POST':
        if request.session.test_cookie_worked():
            request.session.delete_test_cookie()
##登录验证的代码
            return HttpResponse("You're logged in.")
        else:
            return HttpResponse("Please enable cookies and try again.")
    request.session.set_test_cookie()
    return render_to_response('foo/login_form.html')
```


###(3)视图外使用session:
每个session都是一个内部的Django model(由django.contrib.sessions.models定义),由一个随机的32字节哈希串表示.可以用用Django数据库API来存取session。

其表的结构为:

session_key | session_data | expire_date
--- | --- | ---


```
>>> from django.contrib.sessions.models import Session
>>> s = Session.objects.get(pk='2b1189a188b44ad18c35e113ac6ceead')
>>> s.expire_date
>>> datetime.datetime(2018, 2, 8, 9, 13, 17, 668186, tzinfo=<UTC>)
```


需要用get_decoded()来读取实际的session值:

```python
>>> s.session_data
'KGRwMQpTJ19hdXRoX3VzZXJfaWQnCnAyCkkxCnMuMTExY2ZjODI2Yj...'
>>> s.get_decoded()
{'user_id': 42}
```

何时保存Session.
如果Session是一张表,那么需要存储持久化的地方在于:**session发生改变的时候**


```python
# Session is modified.
request.session['foo'] = 'bar'

# Session is modified.
del request.session['foo']

# Session is modified.
request.session['foo'] = {}

```


* 如果SESSION_EXPIRE_AT_BROWSER_CLOSE 设置为 True ，当浏览器关闭时，Django会使cookie失效。
* 默认情况下， SESSION_EXPIRE_AT_BROWSER_CLOSE 设置为 False ，这样，会话cookie可以在用户浏览器中保持有效达 SESSION_COOKIE_AGE 秒（缺省设置是两周，即1,209,600 秒）。
* SESSION_COOKIE_DOMAIN,使用会话cookie（session cookies）的站点。 将它设成一个字符串，就好象 “.example.com” 以用于跨站点（cross-domain）的cookie，或None 以用于单个站点。 默认为None
* SESSION_COOKIE_SECURE,是否在session中使用安全cookie。 如果设置 True , cookie就会标记为安全， 这意味着cookie只会通过HTTPS来传输。默认为false
* Session 数据在需要的时候才会读取。 如果你从不使用 request.session ， Django不会动相关数据库表的一根毛。
* Django session 框架完全而且只能基于cookie。 它不会后退到把会话ID编码在URL中（像某些工具(PHP,JSP)那样）。


关于session部分的源代码位于:
**django.contrib.sessions**中

###三、用户
 Django 用户认证系统处理用户帐号，组，权限以及基于cookie的用户会话。 这个系统一般被称为 auth/auth (认证与授权)系统。 这个系统的名称同时也表明了用户常见的两步处理。 我们需要

  * 验证 (认证) 用户是否是他所宣称的用户(一般通过查询数据库验证其用户名和密码)
  * 验证用户是否拥有执行某种操作的 授权 (通常会通过检查一个权限表来确认)

####1.处理User对象
在view中,存储users主要中 request.user表示当前已经登录的对象,如果用户还没登录,则是一个**AnonymousUser**对象:

```python
if request.user.is_authenticated():
    # Do something for authenticated users.
else:
    # Do something for anonymous users.
``` 


####2.登录验证:
一般的,接收到post来的username,我们一般会去数据库查询该username和password是否存在一行数据,正确的话返回.

django为我们提供了一个函数来解决这个登录问题:

**authenticate()**函数,接收两个函数:username,password

用户名跟密码合法情况返回一个User对象,密码不合法返回None

```python
>>> from django.contrib import auth
>>> user = auth.authenticate(username='john', password='secret')
>>> if user is not None:
...     print "Correct!"
... else:
...     print "Invalid password."
```


####3.view中登录处理:

```python
from django.contrib import auth

def login_view(request):
    username = request.POST.get('username', '')
    password = request.POST.get('password', '')
    user = auth.authenticate(username=username, password=password)
    if user is not None and user.is_active:
        # Correct password, and the user is marked "active"
        auth.login(request, user)
        # Redirect to a success page.
        return HttpResponseRedirect("/account/loggedin/")
    else:
        # Show an error page
        return HttpResponseRedirect("/account/invalid/")
```

登出:

```python
from django.contrib import auth

def logout_view(request):
    auth.logout(request)
    # Redirect to a success page.
    return HttpResponseRedirect("/account/loggedout/")
```

####4.限制未登录用户的访问:

比如查看购物车这样的关系,需要限制未登录的人员.

一个简单粗暴的办法就是检查request.user.is_authenticated(),然后重定向到登录页面.

```python
from django.http import HttpResponseRedirect

def my_view(request):
    if not request.user.is_authenticated():
        return HttpResponseRedirect('/accounts/login/?next=%s' % request.path)
    # ...
```

django帮你实现了一个装饰器:**login_required**,帮你做一下的事情:

* 如果用户没有登录, 重定向到 /accounts/login/ , 把当前绝对URL作为 next 在查询字符串中传递过去, 例如： /accounts/login/?next=/polls/3/ 。
* 如果用户已经登录, 正常地执行视图函数。 视图代码就可以假定用户已经登录了。

```python
from django.contrib.auth.decorators import login_required

@login_required
def my_view(request):
    # ...
    
#如果指定登录url,则为:
@login_required(login_url='/login')
def nextPage(request):
    return HttpResponse("这是登录后的页面!"+str(request.user.username))
```

####5.登录后的权限限制:

比如有一个投票的限制:

```python
def vote(request):
    if request.user.is_authenticated() and request.user.has_perm('polls.can_vote')):
        # vote here
    else:
        return HttpResponse("You can't vote in this poll.")
```

并且Django有一个称为 user_passes_test 的简洁方式。它接受参数然后为你指定的情况生成装饰器

```python
def user_can_vote(user):
    return user.is_authenticated() and user.has_perm("polls.can_vote")

@user_passes_test(user_can_vote, login_url="/login/")
def vote(request):
    # Code here can assume a logged-in user with the correct permission.
```

user_passes_test 使用一个必需的参数： 一个可调用的方法，当存在 User 对象并当此用户允许查看该页面时返回 True 。 注意 user_passes_test 不会自动检查 User

例子中我们也展示了第二个可选的参数 login_url ，它让你指定你的登录页面的URL（默认为 /accounts/login/ ）。 如果用户没有通过测试，那么user_passes_test将把用户重定向到login_url

既然检查用户是否有一个特殊权限是相对常见的任务，Django为这种情形提供了一个捷径： permission_required() 装饰器。 使用这个装饰器，前面的例子可以改写为：

```python
from django.contrib.auth.decorators import permission_required

@permission_required('polls.can_vote', login_url="/login/")
def vote(request):
    # ...
```


####6.一个简单的注册登录例子:

View.py:

```python
from django.shortcuts import render
from django.contrib.auth import logout, login, authenticate
from django.shortcuts import render, redirect, HttpResponse
from django.contrib.auth.hashers import make_password
from django.contrib.auth.decorators import login_required
# Create your views here.
from .forms import *
from django.contrib.auth.models import User
# 注销
def do_logout(request):
    try:
        logout(request)
    except Exception as e:
        print(e)
    redirectPath = request.POST.get('next', request.GET.get('next', ''))
    return redirect(redirectPath)


# 注册
def do_reg(request):
    try:
        redirectPath = request.POST.get('next', request.GET.get('next', ''))
        if request.method == 'POST':
            reg_form = RegForm(request.POST)
            if reg_form.is_valid():
                # 注册
                user = User.objects.create(username=reg_form.cleaned_data["username"],
                                    email=reg_form.cleaned_data["email"],
                                    password=make_password(reg_form.cleaned_data["password"]),)
                user.save()
                print('注册成功')
                # 登录
                user.backend = 'django.contrib.auth.backends.ModelBackend' # 指定默认的登录验证方式
                login(request, user)
                print(redirectPath)

                return redirect(redirectPath)
            else:
                return render(request, 'failure.html', {'reason': reg_form.errors})
        else:
            #如果不是post,则是刚跳转过来的,需要初始化表单 html传过去
            reg_form = RegForm()
            return render(request, 'reg.html', locals())
    except Exception as e:
        print(e)

# 登录
def do_login(request):
    try:
        redirectPath = request.POST.get('next', request.GET.get('next', ''))
        if request.method == 'POST':
            login_form = LoginForm(request.POST)
            if login_form.is_valid():
                # 登录
                username = login_form.cleaned_data["username"]
                password = login_form.cleaned_data["password"]
                user = authenticate(username=username, password=password)
                if user is not None:
                    user.backend = 'django.contrib.auth.backends.ModelBackend' # 指定默认的登录验证方式
                    login(request, user)
                else:
                    return render(request, 'failure.html', {'reason': '登录验证失败'})
                return redirect(request.POST.get('source_url'))
            else:
                return render(request, 'failure.html', {'reason': login_form.errors})
        else:
            login_form = LoginForm()
            return render(request, 'login.html', {'next': redirectPath})
    except Exception as e:
        print(e)
def index(request):
    return render(request,'home.html',locals())

@login_required(login_url='/login',)
def nextPage(request):
    return HttpResponse("这是登录后的页面!"+str(request.user.username))
```

forms.py

```python
# -*- coding:utf-8 -*-
from django import forms

class LoginForm(forms.Form):
    '''
    登录Form
    '''
    username = forms.CharField(widget=forms.TextInput(attrs={"placeholder": "Username", "required": "required",}),
                              max_length=50,error_messages={"required": "username不能为空",})
    password = forms.CharField(widget=forms.PasswordInput(attrs={"placeholder": "Password", "required": "required",}),
                              max_length=20,error_messages={"required": "password不能为空",})

class RegForm(forms.Form):
    '''
    注册表单
    '''
    username = forms.CharField(widget=forms.TextInput(attrs={"placeholder": "Username", "required": "required",}),
                              max_length=50,error_messages={"required": "username不能为空",})
    email = forms.EmailField(widget=forms.TextInput(attrs={"placeholder": "Email", "required": "required",}),
                              max_length=50,error_messages={"required": "email不能为空",})
    password = forms.CharField(widget=forms.PasswordInput(attrs={"placeholder": "Password", "required": "required",}),
                              max_length=20,error_messages={"required": "password不能为空",})
```

urls.py

```python
from django.urls import path
from .views import *

urlpatterns = [
    path('',index,name ='home'),
    path('logout/' ,do_logout, name='logout'),
    path('reg/',do_reg,name='reg'),
    path('login/',do_login,name='login'),
    path('/next/',nextPage,name='next')
]
```

home.html

```html
{% load staticfiles %}
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Title</title>
</head>
<body>

<ul>
    <li><a href="{% url 'reg' %}?next={{ request.path }}">注册</a> </li>
    <li><a href="{% url 'login' %}?next={{ request.path }}">登录</a> </li>
<li><a href="{% url 'next' %}">登陆后点击下一页</a> </li>
<li><a href="{% url 'logout' %}?next={{ request.path }}">登出</a> </li>
    {% block main %}
    {% endblock %}
</ul>
</body>
</html>
```

reg.html

```html
{% load staticfiles %}
<!DOCTYPE html>
<html>
<head>
		<meta charset="utf-8">
		<link href="{% static 'css/reglogin.css' %}" rel='stylesheet' type='text/css' />
		<meta name="viewport" content="width=device-width, initial-scale=1">
</head>
<body>
	<div class="main">
		<div class="header" >
			<h1>Create a Free Account!</h1>
		</div>
		<p></p>
			<form action="{% url 'reg' %}" method="post">
                {% csrf_token %}
				<ul class="left-form">
					<h2>New Account:</h2>
					<li>
						{{ reg_form.username }}
						<div class="clear"> </div>
					</li>
					<li>
						{{ reg_form.email }}
						<div class="clear"> </div>
					</li>
					<li>
						{{ reg_form.url }}
						<div class="clear"> </div>
					</li>
					<li>
                        {{ reg_form.password }}
						<div class="clear"> </div>
					</li>
                    <input type="hidden" name="source_url" value="{{ next }}">
					<input type="submit" value="Create And Login">
					<div class="clear"> </div>
				</ul>
				<div class="clear"> </div>
			</form>
	</div>
</body>
</html>
```

login.html

```html
{% load staticfiles %}
<!DOCTYPE html>
<html>
<head>
		<meta charset="utf-8">
		<link href="css/relogin.css" rel='stylesheet' type='text/css' />
		<meta name="viewport" content="width=device-width, initial-scale=1">
</head>
<body>
	<div class="main">
		<div class="header" >
			<h1>Login!</h1>
		</div>
		<p></p>
			<form action="{% url 'login' %}" method="post">
                {% csrf_token %}
				<ul class="right-form">
					<h2>Login:</h2>
					<li><input type="text" name="username" placeholder="Username" required/></li>
					<li><input type="password" name="password" placeholder="Password" required/></li>
					<input type="hidden" name="source_url" value="{{ next }}">
                    <input type="submit" value="Login" >
					<div class="clear"> </div>
				</ul>
				<div class="clear"> </div>

			</form>
	</div>
</body>
</html>
```


###后续:
无论是登录还是注册还是注销,都要注意是哪个path触发的这三个事件,需要将此path传入next 参数中,方便完成注册或者登录的时候跳转回原来页面








