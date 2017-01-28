using System;
using System.ComponentModel.DataAnnotations;
using System.Reflection;

namespace NpvApi.Dtos.Validators
{
    public class GreaterThanFieldAttribute:ValidationAttribute
    {   
            private string FieldToCompare { get; set; }           

            public GreaterThanFieldAttribute(string fieldToCompare)
            {
                this.FieldToCompare = fieldToCompare;                
            }


            /// <summary>
            /// Same logic has been applied in client also by Aurelia validation rule
            /// </summary>
            /// <param name="value"></param>
            /// <param name="context"></param>
            /// <returns></returns>
            protected override ValidationResult IsValid(object value, ValidationContext context)
            {
                Object instance = context.ObjectInstance;
                Type type = instance.GetType();
                var fieldToCompare = type.GetProperty(this.FieldToCompare);                

                if (fieldToCompare == null)
                {
                    return new ValidationResult(
                        string.Format("Unknown property: {0}", this.FieldToCompare)
                    );
                };

            var fieldToCompareValue = fieldToCompare.GetValue(instance, null) as decimal?;
            var currentValue = value as Decimal?;

            var isValid =
                    fieldToCompare == null ||
                    currentValue == null ||
                    (currentValue >= fieldToCompareValue);

                return
                    isValid ? ValidationResult.Success :
                    new ValidationResult(this.FormatErrorMessage(context.DisplayName));
            }
        }
}
