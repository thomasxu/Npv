using System;
using System.ComponentModel.DataAnnotations;
using System.Reflection;

namespace NpvApi.Dtos.Validators
{
    public class LessThanOrEqualToDifferenceOfTwoFieldsAndPositiveAttribute : ValidationAttribute
    {
        private string LowerPropertyName { get; set; }
        private string UpperPropertyName { get; set; }

        public LessThanOrEqualToDifferenceOfTwoFieldsAndPositiveAttribute(string lowerRatePropertyName, string upperRatePropertyName)
        {
            this.LowerPropertyName = lowerRatePropertyName;
            this.UpperPropertyName = upperRatePropertyName;
        }


        /// <summary>
        /// Same logic has been applied in client by Aurelia validation rule
        /// </summary>
        /// <param name="value"></param>
        /// <param name="context"></param>
        /// <returns></returns>
        protected override ValidationResult IsValid(object value, ValidationContext context)
        {
            Object instance = context.ObjectInstance;
            Type type = instance.GetType();
            var lowerRateProprty = type.GetProperty(this.LowerPropertyName);
            var upperRateProprty = type.GetProperty(this.UpperPropertyName);

            if(lowerRateProprty == null)
            {
                return new ValidationResult(
                    string.Format("Unknown property: {0}", this.LowerPropertyName)
                );
            };
            if (upperRateProprty == null) {
                return new ValidationResult(
                   string.Format("Unknown property: {0}", this.LowerPropertyName)
               );
            };


            var lowerRateProprtyValue = lowerRateProprty.GetValue(instance, null) as decimal?;
            var upperRateProprtyValue = upperRateProprty.GetValue(instance, null) as decimal?;
            var increment = value as decimal?;
            

            var isValid = 
                lowerRateProprtyValue == null || 
                upperRateProprtyValue == null || 
                increment == null ||
                (increment.Value >= 0 && increment.Value <= upperRateProprtyValue - lowerRateProprtyValue);

            return
                isValid? ValidationResult.Success:
                new ValidationResult(this.FormatErrorMessage(context.DisplayName));
        }
    }
}
