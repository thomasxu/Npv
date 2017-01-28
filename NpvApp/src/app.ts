import {inject} from "aurelia-framework";
import {Router} from "aurelia-router";

@inject(Router)
    export class App {      
    router: Router;

    configureRouter(config, router: Router) {
        this.router = router;

        config.title = "Octet";
        config.map([
            { route: [""], moduleId: "./resources/elements/npv-calculator", nav: true, title: "Calculator" },
            { route: "about", moduleId: "./resources/elements/about", nav: true, title: "About" },            
        ]);
    }
}
