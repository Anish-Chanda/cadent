import React, { useState } from "react"
import { Link } from "@tanstack/react-router"
import { Eye, EyeOff } from "lucide-react"
import { cn } from "@/lib/utils"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import {
  Field,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field"
import { Input } from "@/components/ui/input"

export interface LoginFormFields {
  name?: string
  email: string
  password: string
}

interface LoginFormProps extends Omit<React.ComponentProps<"div">, "onSubmit"> {
  mode: "login" | "signup"
  onSubmit: (fields: LoginFormFields) => void
  isLoading?: boolean
  error?: string | null
}

function PasswordInput({
  id,
  name,
  disabled,
  visible,
  onToggleVisible,
}: {
  id: string
  name: string
  disabled?: boolean
  visible: boolean
  onToggleVisible: () => void
}) {
  return (
    <div className="relative">
      <Input
        id={id}
        name={name}
        type={visible ? "text" : "password"}
        required
        disabled={disabled}
        className="pr-10"
      />
      <button
        type="button"
        tabIndex={-1}
        onClick={onToggleVisible}
        className="absolute inset-y-0 right-0 flex items-center px-3 text-muted-foreground hover:text-foreground"
        aria-label={visible ? "Hide password" : "Show password"}
      >
        {visible ? <EyeOff className="size-4" /> : <Eye className="size-4" />}
      </button>
    </div>
  )
}

export function LoginForm({
  className,
  mode,
  onSubmit,
  isLoading = false,
  error,
  ...props
}: LoginFormProps) {
  const isLogin = mode === "login"
  const [confirmError, setConfirmError] = useState<string | null>(null)
  const [passwordVisible, setPasswordVisible] = useState(false)

  function togglePasswordVisible() {
    setPasswordVisible((v) => !v)
  }

  function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault()
    setConfirmError(null)
    const form = e.currentTarget
    const data = new FormData(form)

    if (!isLogin) {
      const password = data.get("password") as string
      const confirmPassword = data.get("confirmPassword") as string
      if (password !== confirmPassword) {
        setConfirmError("Passwords do not match.")
        return
      }
    }

    onSubmit({
      name: data.get("name") as string | undefined,
      email: data.get("email") as string,
      password: data.get("password") as string,
    })
  }

  return (
    <div className={cn("flex flex-col gap-6", className)} {...props}>
      <Card>
        <CardHeader className="text-center">
          <CardTitle className="text-xl">
            {isLogin ? "Welcome back" : "Create an account"}
          </CardTitle>
          <CardDescription>
            {isLogin
              ? "Sign in to your Cadent account"
              : "Enter your details to get started"}
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit}>
            <FieldGroup>
              {!isLogin && (
                <Field>
                  <FieldLabel htmlFor="name">Name</FieldLabel>
                  <Input
                    id="name"
                    name="name"
                    type="text"
                    placeholder="Jane Doe"
                    required
                    disabled={isLoading}
                  />
                </Field>
              )}
              <Field>
                <FieldLabel htmlFor="email">Email</FieldLabel>
                <Input
                  id="email"
                  name="email"
                  type="email"
                  placeholder="you@example.com"
                  required
                  disabled={isLoading}
                />
              </Field>
              <Field>
                <FieldLabel htmlFor="password">Password</FieldLabel>
                <PasswordInput
                  id="password"
                  name="password"
                  disabled={isLoading}
                  visible={passwordVisible}
                  onToggleVisible={togglePasswordVisible}
                />
              </Field>
              {!isLogin && (
                <Field>
                  <FieldLabel htmlFor="confirmPassword">Confirm password</FieldLabel>
                  <PasswordInput
                    id="confirmPassword"
                    name="confirmPassword"
                    disabled={isLoading}
                    visible={passwordVisible}
                    onToggleVisible={togglePasswordVisible}
                  />
                  {confirmError && <FieldError>{confirmError}</FieldError>}
                </Field>
              )}
              {error && <FieldError>{error}</FieldError>}
              <Field>
                <Button type="submit" disabled={isLoading}>
                  {isLoading
                    ? isLogin
                      ? "Signing in…"
                      : "Creating account…"
                    : isLogin
                      ? "Sign in"
                      : "Create account"}
                </Button>
                <FieldDescription className="text-center">
                  {isLogin ? (
                    <>
                      Don&apos;t have an account?{" "}
                      <Link to="/signup" className="underline underline-offset-4">
                        Sign up
                      </Link>
                    </>
                  ) : (
                    <>
                      Already have an account?{" "}
                      <Link to="/login" search={{ redirect: undefined }} className="underline underline-offset-4">
                        Sign in
                      </Link>
                    </>
                  )}
                </FieldDescription>
              </Field>
            </FieldGroup>
          </form>
        </CardContent>
      </Card>
    </div>
  )
}
