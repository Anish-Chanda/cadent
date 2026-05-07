import type * as React from "react";

import { Input } from "@/components/ui/input";

type DatePickerProps = Omit<
	React.ComponentProps<"input">,
	"type" | "value" | "onChange"
> & {
	value: string;
	onChange: (value: string) => void;
};

function DatePicker({ value, onChange, ...props }: DatePickerProps) {
	return (
		<Input
			type="date"
			value={value}
			onChange={(event) => onChange(event.target.value)}
			{...props}
		/>
	);
}

export { DatePicker };
