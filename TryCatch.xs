#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "hook_op_check.h"
#include "hook_op_ppaddr.h"

STATIC OP* unwind_return (pTHX_ OP *op, void *user_data) {
  dSP;
  CV *unwind;

  PERL_UNUSED_VAR(user_data);
  PUSHMARK(SP);
  XPUSHs(sv_2mortal(newSViv(3)));
  PUTBACK;

  call_pv("Scope::Upper::CALLER", G_SCALAR);

  SPAGAIN;


  // call_pv("Scope::Upper::unwind", G_VOID);
  // Can't use call_sv et al. since it resets PL_op.
 
  unwind = get_cv("Scope::Upper::unwind", 0);
  XPUSHs( (SV*)unwind);
  PUTBACK;

  return CALL_FPTR(PL_ppaddr[OP_ENTERSUB])(aTHX);
}

// Hook the OP_RETURN iff we are in hte same file as originally compiling.
STATIC OP* check_return (pTHX_ OP *op, void *user_data) {
  
  const char* file = SvPV_nolen( (SV*)user_data );
  const char* cur_file = CopFILE(&PL_compiling);
  if (strcmp(file, cur_file))
    return op;
  hook_op_ppaddr(op, unwind_return, NULL);
  return op;
}

MODULE = TryCatch PACKAGE = TryCatch::XS

void 
install_return_op_check()
  CODE:
    // Code stole from Scalar::Util::dualvar
    UV id;
    char* file = CopFILE(&PL_compiling);
    STRLEN len = strlen(file);

    ST(0) = newSV(0);

    (void)SvUPGRADE(ST(0),SVt_PVNV);
    sv_setpvn(ST(0),file,len);

    id = hook_op_check( OP_RETURN, check_return, ST(0) );
#ifdef SVf_IVisUV
    SvUV_set(ST(0), id);
    SvIOK_on(ST(0));
    SvIsUV_on(ST(0));
#else
    SvIV_set(ST(0), id);
    SvIOK_on(ST(0));
#endif

    XSRETURN(1);

void
uninstall_return_op_check(id)
SV* id
  CODE:
#ifdef SVf_IVisUV
    UV uiv = SvUV(id);
#else
    UV uiv = SvIV(id);
#endif
    hook_op_check_remove(OP_RETURN, uiv);
    //SvREFCNT_dec( id );
  OUTPUT:
