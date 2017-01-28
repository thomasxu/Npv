
export class NpvOption {
  outflow: number;
  inflows: Inflow[];
  rateOption: RateOption;


  constructor(inflowCount: number) {
    this.inflows = new Array<Inflow>();

    for(var i = 0; i < inflowCount; i++)
    {
        this.inflows.push({value: undefined});
    }
    this.rateOption = new RateOption();
  }
}

export class RateOption
{
  lowerDiscount: number;
  upperDiscount: number;
  discountIncrement: number;
}

export class Inflow {
  value?: number
}

