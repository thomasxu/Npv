import { autoinject, bindable } from 'aurelia-framework';
import { inject, NewInstance } from 'aurelia-framework'
import { ValidationRules, ValidationController } from 'aurelia-validation'
import { BootstrapFormRenderer } from '../utility/bootstrap-form-renderer'
import { NpvOption, RateOption, Inflow } from '../models/npv-option'
import { NpvResult } from '../models/npv-result'
import { NpvService } from '../services/npv-service'

@inject(NewInstance.of(ValidationController), NpvService)
export class NpvCalculator {
  //How many inflow input will be rendered
  @bindable initialInflowCount: number = 5;
  //calculation input parameters
  npvOption: NpvOption;
  //calculation output parameters
  npvResults: NpvResult[];
  //For showing server error e.g. when api is not avaliable
  hasServerError: boolean = undefined;
  readonly RequiredValidationMsg: string = "Required";
  readonly MaxInflowCount = 15;


  constructor(private validationController: ValidationController, private npvService: NpvService) {
    console.log(this.initialInflowCount);

    //Initialise how many inflows will be rendered initially and add validation rules    
    this.initViewModelAddValidationRules();

    this.validationController.addRenderer(new BootstrapFormRenderer());
  }

  removeInflow(index:number) {    
    if(this.npvOption.inflows.length <= 1)
    {
        //Do not have time for adding bootstrap model dialog just alert here
        alert("You must have at least 1 inflow.");
        return false;
    }
    this.npvOption.inflows.splice(index, 1);    
  }

  addInflow(index:number) {
     if(this.npvOption.inflows.length >= 15)
    {
        //Do not have time for adding bootstrap model dialog just alert here
        alert("Only 15 inflows is allow.");
        return false;
    }

    this.npvOption.inflows.splice(index + 1, 0, {value: undefined});
    this.applyValidationRules();
  }

  calculate() {      
    //Submit the form if pass validation
    this.validationController
      .validate()
      .then(v => {
        if (v.valid) {
          this.calculateImpl();
        }
      });
  }

  //Call service to get npv calculation result
  calculateImpl() {
    this.hasServerError = undefined;    
    this.npvService.Calculate(this.npvOption)
      .then(r => {                   
        this.hasServerError = false;
        console.log(r);        
        this.npvResults = r
      }).bind(this)
      .catch(function (err) {                
        console.error(err);        
        this.hasServerError = true;
      });
  }

  reset() {
    this.hasServerError = undefined;
    this.npvResults = undefined;
    this.initViewModelAddValidationRules();
  }

  initViewModelAddValidationRules() {
    this.validationController.reset();
    //Init calculator input parameters
    this.npvOption = new NpvOption(this.initialInflowCount);

    this.createCustomValidationRules();
    this.applyValidationRules();
  }

  createCustomValidationRules() {
    ValidationRules.customRule(
      'positiveNumber',
      (value, obj) => {
        var numberValue = parseFloat(value);
        return isNaN(numberValue) || numberValue > 0;
      },
      "Positive number only"
    );


    ValidationRules.customRule(
      'negativeNumber',
      (value, obj) => {
        let numberValue = parseFloat(value);
        return isNaN(numberValue) || numberValue < 0;
      },
      "Negative number only");


    ValidationRules.customRule(
      'upperRateGreaterEqualToLowerRateAndPositive',
      (value, obj) => {
        let upperRate = parseFloat(value);
        let lowerRate = this.npvOption.rateOption.lowerDiscount;

        return isNaN(upperRate) || isNaN(lowerRate) || (upperRate > 0 && upperRate >= lowerRate)
      },
      "Upper discount must be positive and greater than or equal to lower discount"
    );

     ValidationRules.customRule(
      'LessThanOrEqualToDifferenceOfDiscountsAndPositive',
      (value, obj) => {
        let lowerDiscount: number = this.npvOption.rateOption.lowerDiscount;
        let upperDiscount: number = this.npvOption.rateOption.upperDiscount;

        let increment = parseFloat(value);
        if (isNaN(increment) ||
          isNaN(lowerDiscount) ||
          isNaN(upperDiscount) ||
          (increment >= 0 &&  increment <= upperDiscount-lowerDiscount)
        ) {
          return true;
        }
      },
      " Discount Increment must be positive and greater than or equal to difference of lower and higher discounts"
    );
  }

  applyValidationRules() {
    let inflows = this.npvOption.inflows;

    for (var i = 0; i < inflows.length; i++) {
      ValidationRules
        .ensure((ifs: Inflow) => ifs.value)
        .required().withMessage(this.RequiredValidationMsg)
        .satisfiesRule("positiveNumber")
        .on(inflows[i]);
    }


    ValidationRules
      .ensure((opt: NpvOption) => opt.outflow)
      .required().withMessage(this.RequiredValidationMsg)
      .satisfiesRule("positiveNumber")
      .on(this.npvOption)


    ValidationRules
      .ensure((opt: RateOption) => opt.lowerDiscount)
      .satisfiesRule("positiveNumber")
      .required().withMessage(this.RequiredValidationMsg)
      .ensure((opt: RateOption) => opt.upperDiscount)      
      .satisfiesRule("upperRateGreaterEqualToLowerRateAndPositive")
      .required().withMessage(this.RequiredValidationMsg)
      .ensure((opt: RateOption) => opt.discountIncrement)
      // discountIncrement must <= UpperDiscount - LowerDiscount and >=0
      .satisfiesRule("LessThanOrEqualToDifferenceOfDiscountsAndPositive")
      .required().withMessage(this.RequiredValidationMsg)
      .on(this.npvOption.rateOption)
  }
}

