#django源码阅读

##入口文件：

```python
#!/usr/bin/env python
import os
import sys

if __name__ == "__main__":
    # 将settings模块设置到环境变量中
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "webui.settings")
    from django.core.management import execute_from_command_line
    # 执行命令
    execute_from_command_line(sys.argv)
```

执行execute_from_command_line方法

```python
# 文件名 django.core.management/init.py
def execute_from_command_line(argv=None):
    """Run a ManagementUtility."""
    #执行一个ManagementUtility类
    utility = ManagementUtility(argv)
    utility.execute()
    
    
class ManagementUtility:
    """
    封装django-admin和manage.py实用程序的逻辑.
    """
    def __init__(self, argv=None):
    
        #区分参数是一个还是一个列表
        self.argv = argv or sys.argv[:]
        #调用函数是main.py还是python
        self.prog_name = os.path.basename(self.argv[0])
        if self.prog_name == '__main__.py':
            self.prog_name = 'python -m django'
        self.settings_exception = None



    def execute(self):
        """
       给出命令行参数，找出哪个子命令正在运行，创建适合于该命令的解析器，并运行它
        """
        try:
            subcommand = self.argv[1]
            ##拿到传入参数
        except IndexError:
            subcommand = 'help' 
##出错情况
# Display help if no arguments were given.

# Preprocess options to extract --settings and --pythonpath.
# These options could affect the commands that are available, so they
        # must be processed early.
        parser = CommandParser(None, usage="%(prog)s subcommand [options] [args]", add_help=False)
        parser.add_argument('--settings')
        parser.add_argument('--pythonpath')
        parser.add_argument('args', nargs='*')  # catch-all
        try:
            options, args = parser.parse_known_args(self.argv[2:])
            handle_default_options(options)
        except CommandError:
            pass  # Ignore any option errors at this point.


#运行注册的APP
        try:
            settings.INSTALLED_APPS
        except ImproperlyConfigured as exc:
            self.settings_exception = exc
        except ImportError as exc:
            self.settings_exception = exc

        if settings.configured:
            # Start the auto-reloading dev server even if the code is broken.
            # The hardcoded condition is a code smell but we can't rely on a
            # flag on the command class because we haven't located it yet.
            if subcommand == 'runserver' and '--noreload' not in self.argv:
            
                ##开启django自带服务器,且不是重新加载Django模块
                try:
                    ##check 初始化参数是否有错
                    autoreload.check_errors(django.setup)()
                except Exception:
                    # The exception will be raised later in the child process
                    # started by the autoreloader. Pretend it didn't happen by
                    # loading an empty list of applications.
                    apps.all_models = defaultdict(OrderedDict)
                    apps.app_configs = OrderedDict()
                    apps.apps_ready = apps.models_ready = apps.ready = True

                    # Remove options not compatible with the built-in runserver
                    # (e.g. options for the contrib.staticfiles' runserver).
                    # Changes here require manually testing as described in
                    # #27522.
                    _parser = self.fetch_command('runserver').create_parser('django', 'runserver')
                    _options, _args = _parser.parse_known_args(self.argv[2:])
                    for _arg in _args:
                        self.argv.remove(_arg)

            # In all other cases, django.setup() is required to succeed.
            else:
                django.setup()
        ##执行
        self.autocomplete()

        if subcommand == 'help':
            ##如果是help参数,执行self.main_help_text()方法获得帮助信息
            if '--commands' in args:
                sys.stdout.write(self.main_help_text(commands_only=True) + '\n')
            elif not options.args:
                sys.stdout.write(self.main_help_text() + '\n')
            else:
                self.fetch_command(options.args[0]).print_help(self.prog_name, options.args[0])
        # Special-cases: We want 'django-admin --version' and
        # 'django-admin --help' to work, for backwards compatibility.
        elif subcommand == 'version' or self.argv[1:] == ['--version']:
            sys.stdout.write(django.get_version() + '\n')
        elif self.argv[1:] in (['--help'], ['-h']):
            sys.stdout.write(self.main_help_text() + '\n')
        else:
            self.fetch_command(subcommand).run_from_argv(self.argv)


```



**ManagementUtility类的excute方法**,当解析的的命令是 runserver 时，会有两条路，第一个是会自动重装的路线，通过 autoreload.check_errors(django.setup)() 代理完成。另一个路线是参数中有 --noreload 时，就用 django.setup() 来启动服务。
服务启动后,检查subcommand
如果是help命令,则执行self.main_help_text()方法得到帮助信息,
如果不是help命令,最后一个 执行self.fetch_command(subcommand).run_from_argv(self.argv)
这边分两步，一步是获取执行命令所需要的类，其次是将命令参数作为参数传递给执行函数执行：

```python
    def fetch_command(self, subcommand):
    
    ##执行相应的command
        """
        Try to fetch the given subcommand, printing a message with the
        appropriate command called from the command line (usually
        "django-admin" or "manage.py") if it can't be found.
        """
        # Get commands outside of try block to prevent swallowing exceptions
        commands = get_commands()
        try:
            app_name = commands[subcommand]
        except KeyError:
            if os.environ.get('DJANGO_SETTINGS_MODULE'):
                # If `subcommand` is missing due to misconfigured settings, the
                # following line will retrigger an ImproperlyConfigured exception
                # (get_commands() swallows the original one) so the user is
                # informed about it.
                settings.INSTALLED_APPS
            else:
                sys.stderr.write("No Django settings specified.\n")
            sys.stderr.write(
                "Unknown command: %r\nType '%s help' for usage.\n"
                % (subcommand, self.prog_name)
            )
            sys.exit(1)
        if isinstance(app_name, BaseCommand):
            # If the command is already loaded, use it directly.
            klass = app_name
        else:
            klass = load_command_class(app_name, subcommand)
        return klass
```

```
def get_commands():
    """
    Return a dictionary mapping command names to their callback applications.

    Look for a management.commands package in django.core, and in each
    installed application -- if a commands package exists, register all
    commands in that package.

    Core commands are always included. If a settings module has been
    specified, also include user-defined commands.

    The dictionary is in the format {command_name: app_name}. Key-value
    pairs from this dictionary can then be used in calls to
    load_command_class(app_name, command_name)

    If a specific version of a command must be loaded (e.g., with the
    startapp command), the instantiated module can be placed in the
    dictionary in place of the application name.

    The dictionary is cached on the first call and reused on subsequent
    calls.
    """
    commands = {name: 'django.core' for name in find_commands(__path__[0])}
    ##django.core模块
    if not settings.configured:
        return commands

##自定义模块
    for app_config in reversed(list(apps.get_app_configs())):
        path = os.path.join(app_config.path, 'management')
        commands.update({name: app_config.name for name in find_commands(path)})

    return commands

```
get_commands函数返回的是 命令与django模块的映射:

```
{
    "makemessages": "django.core",
    "makemigrations": "django.core",
    "migrate": "django.core",
    "runserver": "django.contrib.staticfiles",
    "startapp": "django.core",
    "startproject": "django.core",
    "createsuperuser": "django.contrib.auth"
    ...
}
```

load_command_class动态加载模块

```python
def load_command_class(app_name, name):
    """
    给定一个模块和命令,执行响应的模块命令
    """
    module = import_module('%s.management.commands.%s' % (app_name, name))
    return module.Command()

```

如执行**runserver**的时候,执行的是:
**django.contrib.staticfiles.management.commands.runserver**模块的command类的实例,然后执行run_from_argv(self.argv)方法



django.core.management.base.py

```python
    def run_from_argv(self, argv):
     
        self._called_from_command_line = True
        parser = self.create_parser(argv[0], argv[1])

        options = parser.parse_args(argv[2:])
        #对象转成字典
        cmd_options = vars(options)
        # Move positional args out of options to mimic legacy optparse
        args = cmd_options.pop('args', ())
        handle_default_options(options)
        try:
            ##加载相应相应的命令运行
            self.execute(*args, **cmd_options)
        except Exception as e:
            if options.traceback or not isinstance(e, CommandError):
                raise

            # SystemCheckError takes care of its own formatting.
            if isinstance(e, SystemCheckError):
                self.stderr.write(str(e), lambda x: x)
            else:
                self.stderr.write('%s: %s' % (e.__class__.__name__, e))
            sys.exit(1)
        finally:
            try:
                connections.close_all()
            except ImproperlyConfigured:
                # Ignore if connections aren't setup at this point (e.g. no
                # configured settings).
                pass


```


```python
    def execute(self, *args, **options):
        """
        Try to execute this command, performing system checks if needed (as
        controlled by the ``requires_system_checks`` attribute, except if
        force-skipped).
        """
        if options['no_color']:
            self.style = no_style()
            self.stderr.style_func = None
        if options.get('stdout'):
            self.stdout = OutputWrapper(options['stdout'])
        if options.get('stderr'):
            self.stderr = OutputWrapper(options['stderr'], self.stderr.style_func)

        saved_locale = None
        if not self.leave_locale_alone:
            # Deactivate translations, because django-admin creates database
            # content like permissions, and those shouldn't contain any
            # translations.
            from django.utils import translation
            saved_locale = translation.get_language()
            translation.deactivate_all()

        try:
            if self.requires_system_checks and not options.get('skip_checks'):
                self.check()
            if self.requires_migrations_checks:
                self.check_migrations()
            output = self.handle(*args, **options)
            if output:
                if self.output_transaction:
                    connection = connections[options.get('database', DEFAULT_DB_ALIAS)]
                    output = '%s\n%s\n%s' % (
                        self.style.SQL_KEYWORD(connection.ops.start_transaction_sql()),
                        output,
                        self.style.SQL_KEYWORD(connection.ops.end_transaction_sql()),
                    )
                self.stdout.write(output)
        finally:
            if saved_locale is not None:
                translation.activate(saved_locale)
        return output
```





