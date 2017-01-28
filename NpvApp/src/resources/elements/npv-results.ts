import {bindable} from 'aurelia-framework';
import {NpvResult} from '../models/npv-result'

export class NpvResults {
  @bindable results:NpvResult[];
}

