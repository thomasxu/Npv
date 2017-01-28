import {bindable} from 'aurelia-framework';

export class About {
  @bindable value = "Thomas";

  valueChanged(newValue, oldValue) {

  }
}

