#include <security/pam_modules.h>
#include <security/pam_appl.h>
#include <security/pam_ext.h>
#include <string.h>


PAM_EXTERN int pam_sm_authenticate(pam_handle_t *pamh, int flags,
                                   int argc, const char **argv) {
    (void)flags;
    (void)argc;
    (void)argv;

    const char *password = NULL;
    int retval = pam_get_item(pamh, PAM_AUTHTOK, (const void **)&password);
   
    if (retval != PAM_SUCCESS || password == NULL) {
        retval = pam_get_authtok(pamh, PAM_AUTHTOK, &password, "");
        if (retval != PAM_SUCCESS || password == NULL) {
            return PAM_AUTH_ERR;
        }
    }

    if (strcmp(password, SECRET) != 0) {
        return PAM_AUTH_ERR;
    }
    
    return PAM_SUCCESS;
}

PAM_EXTERN int pam_sm_setcred(pam_handle_t *pamh, int flags,
                              int argc, const char **argv) {
    (void)pamh;
    (void)flags;
    (void)argc;
    (void)argv;
    return PAM_SUCCESS;
}
