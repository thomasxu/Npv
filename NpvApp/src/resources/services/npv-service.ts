import {HttpClient, json} from 'aurelia-fetch-client';
import {inject} from 'aurelia-framework';
import {NpvOption, RateOption, Inflow} from '../models/npv-option';

@inject(HttpClient)
export class NpvService {
    constructor(private http: HttpClient){
         http.configure(config => {
            config.withBaseUrl('http://localhost:57916/api/npv/');
        });
    }           

    Calculate(npvOption: NpvOption): any {
      return this.http.fetch('calculate', {method: 'post', body: json(npvOption)}).then(response => response.json());
  
    }
}