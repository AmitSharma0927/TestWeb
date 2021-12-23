#pragma warning disable 108, 8610
#pragma warning disable 8617, 8714
#pragma warning disable 626, 824
namespace testweb
{
    public unsafe class MvcApplication : System.Web.HttpApplication
    {
        protected void Application_Start() => throw null;
    }

    public unsafe class BundleConfig
    {
        public static void RegisterBundles(System.Web.Optimization.BundleCollection bundles) => throw null;
    }

    public unsafe class FilterConfig
    {
        public static void RegisterGlobalFilters(System.Web.Mvc.GlobalFilterCollection filters) => throw null;
    }

    public unsafe class RouteConfig
    {
        public static void RegisterRoutes(RouteCollection routes) => throw null;
    }

    namespace Controllers
    {
        public unsafe class HomeController : System.Web.Mvc.Controller
        {
            public System.Web.Mvc.ActionResult Index() => throw null;
            public System.Web.Mvc.ActionResult About() => throw null;
            public System.Web.Mvc.ActionResult Contact() => throw null;
        }

        public unsafe class StudentController : System.Web.Mvc.Controller
        {
            public System.Web.Mvc.ActionResult Index() => throw null;
            public System.Web.Mvc.ActionResult Details(int id) => throw null;
            public System.Web.Mvc.ActionResult Create() => throw null;
            public System.Web.Mvc.ActionResult Create(System.Web.Mvc.FormCollection collection) => throw null;
            public System.Web.Mvc.ActionResult Edit(int id) => throw null;
            public System.Web.Mvc.ActionResult Edit(int id, System.Web.Mvc.FormCollection collection) => throw null;
            public System.Web.Mvc.ActionResult Delete(int id) => throw null;
            public System.Web.Mvc.ActionResult Delete(int id, System.Web.Mvc.FormCollection collection) => throw null;
        }
    }
}

namespace System
{
    namespace Web
    {
        public class HttpApplication
        {
        }
    }
}

public class RouteCollection
{
}