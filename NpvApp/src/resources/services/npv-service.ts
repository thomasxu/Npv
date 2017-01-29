import {HttpClient, json} from 'aurelia-fetch-client';
import {inject} from 'aurelia-framework';
import {NpvOption, RateOption, Inflow} from '../models/npv-option';
import * as appConfig from '../../environment';

@inject(HttpClient)
export class NpvService {   

    constructor(private http: HttpClient){
         http.configure(config => {
            config.withBaseUrl(appConfig.default.baseUrlNpvService);
        });
    }           

    Calculate(npvOption: NpvOption): any {
      return this.http.fetch('calculate', {method: 'post', body: json(npvOption)}).then(response => 
      {   
          //Bad request for client input (Model validation fail on server side
          //but pass in client side, should never happen)          
          if(response.status == 400)
          {
            throw new Error("Model valiation fail on server side");            
          }

          return response.json();
      });
  
    }
}