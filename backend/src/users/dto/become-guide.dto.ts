import { IsEmail, IsString, MinLength, MaxLength } from 'class-validator';

export class BecomeGuideDto {
  @IsEmail()
  email: string;

  @IsString()
  @MinLength(6)
  @MaxLength(20)
  phone: string;
}
